include("axesquadrants.jl") #module aq

mutable struct Simplehptstruct
    M::Array{Int64,2}
    unreservedonarrival::BitArray{2}
    unreservedafterarrival1::BitArray{2}
    unreservedafterarrival2::BitArray{2}
    unreservedafterarrival3::BitArray{2}

    m1::Array{Int64,2}
    g1::Array{Int64,2}

    m2::Array{Int64,2}
    g2::Array{Int64,2}

    m3::Array{Int64,2}
    g3::Array{Int64,2}

    hpt::Array{Float64,3}
end

mutable struct PersonalM
    preservedALL::BitArray{3}
    pMa::Array{Int64,2}
    pMmultiplier::Array{Int64,2}
end

function get_closestdrop(sz::Tuple{Int64,Int64}, p_myship::CartesianIndex{2}, Pmydroppoints::Array{CartesianIndex{2},1}, shipyardfactor::Int64)
    #shipyardfactor: make it x times longer than it actually is to shipyard in order to not block it in some cases
    dropdists=[sum(abs.(delta(sz, p_myship, Pmydroppoints[i]))) for i=1:length(Pmydroppoints)]
    dropdists[1] = dropdists[1]*shipyardfactor
    p_closestdrop = Pmydroppoints[findmin(dropdists)[2]]
    return p_closestdrop
end

function pick_target(s::State, halitemap::Halitemap, vectors::Vectors, matrices::Matrices, filters::Filters, positions::Positions, various::Various, shouldgenerateship::Bool)
    #For any reader: warning; the structure of this function is more like a working document than ana function. It contains the main ideas of my bot.

    turn = various.turn
    M = halitemap.M
    Mmultiplier = filters.multiplier
    Mlc = halitemap.leavecost
    Pmyships = positions.myships
    IDmyships = various.IDmyships
    IDmyships_full = s.IDmyships_full
    Pmydroppoints = positions.mydroppoints
    Vgameisending = vectors.gameisending
    Minspired = filters.inspired
    Minspiredcloseby = filters.inspiredcloseby
    turns_remaining = various.turns_remaining
    Vmyshipshalite = vectors.myshipshalite
    Pdesirednewdropoffs = positions.desirednewdropoffs
    Menemyshipshalite = matrices.enemyshipshalite
    Mmydropointiscloser = filters.mydropointiscloser
    MIhavemoreshipsclose = filters.Ihavemoreshipsclose
    Penemyships = positions.enemyships
    Venemyhipshalite = vectors.enemyshipshalite
    Mmydroppointsnearby = filters.mydroppointisnearby
    NPlayers = various.NPlayers
    Penemydroppoints = positions.enemydroppoints
    MEnemyhavemoreshipsclose = filters.Enemyhavemoreshipsclose
    Menemyshipsnearby = filters.enemyshipisnearby


    sz=size(M)
    Nmyships=length(Pmyships)

    Mones=ones(Int, sz)
    gameisending = any(Vgameisending)
    symhalite_remaining=sum(M)
    halitefrac_remaining=symhalite_remaining/s.sumhalite_tick1
    meanhalite_remaining=symhalite_remaining/prod(sz)
    
    thresh=round(Int64, 0.6666*meanhalite_remaining)
    thresh_movefaster = round(Int64, meanhalite_remaining)

    if Nmyships<6 && turn<100
        thresh = round(Int64, 0.6666*s.sumhalite_tick1/prod(sz))
    end

    MAXFUTURE=50
    MAXFUTURE_modifyhalite=50
    Ma=copy(M)
    
    target = Array{CartesianIndex{2}}(undef, Nmyships)
    dir = zeros(Int, Nmyships)
    reservedALL=falses(sz[1],sz[2],MAXFUTURE)

    #PRE reserve positions of ships that will not be able to move
    n_cantmove=Mlc[Pmyships].>Vmyshipshalite
    mustbeprereserved = Pmyships[n_cantmove]
    reservedALL[mustbeprereserved,1] .= true

    if turn<6
        reservedALL[positions.myshipyard,1:MAXFUTURE] .= true
    end

    #PREALLOCATE METRICS used by get_mapmetrics!()
    mapmetrics=[[aq.Mapmetrics(0, #tickscenter_aftermined
    0, #minedcenter_aftermined
    0, #gainedcenter_aftermined
    Array{Float64}(undef, sz), #hpt 
    Array{CartesianIndex{2}}(undef, sz), #ci_camefrom
    Array{Int64}(undef, sz), #dirfrom
    Array{Int64}(undef, sz), #arrivalgained
    Array{Int64}(undef, sz), #arrivalticks
    Array{Int64}(undef, sz), #arrivalcost
    Array{Int64}(undef, sz),#carrying_aftermined
    Array{Int64}(undef, sz), #tickshere
    Array{Int64}(undef, sz)) for _=1:Nmyships] for _=1:2] #minedhere

    d= [[aq.Dirmetrics(0,#arrivalticks
    0,#arrivalgained
    0,#arrivalcost
    0,#tickshere_beforemove
    0,#minedhere_beforemove
    0,#gainedhere_beforemove
    0,#tickshere_aftermoved
    0,#minedhere_aftermoved
    0) for _=1:4] for _=1:Nmyships]#gainedhere_aftermoved

    personalM = PersonalM(falses(sz[1],sz[2],MAXFUTURE),
    Array{Int64}(undef, sz),
    Array{Int64}(undef, sz))


    shipsonthewaytonewdropoff=0
    fullshipsonthewaytonewdropoff=0

    Pmydroppointsplus=[Pmydroppoints; Pdesirednewdropoffs]

    ticks2drop_mine=zeros(Int,Nmyships)
    ticks2drop_fast=zeros(Int,Nmyships)
    sumexplored_mine=zeros(Int,Nmyships)
    sumexplored_fast=zeros(Int,Nmyships)
    carryingdrop=zeros(Int,Nmyships)
    hptb=ones(Nmyships).*-Inf
    hptb_full=ones(Nmyships).*-Inf
    cib = Array{CartesianIndex{2}}(undef, Nmyships)
    cib_full = Array{CartesianIndex{2}}(undef, Nmyships)
    p_closestdrop = Array{CartesianIndex{2}}(undef, Nmyships)
    p_closestEdrop = Array{CartesianIndex{2}}(undef, Nmyships)

    simplehptstruct = Simplehptstruct(Array{Int64}(undef, sz),
        falses(sz),
        falses(sz),
        falses(sz),
        falses(sz),
        Array{Int64}(undef, sz),
        Array{Int64}(undef, sz),
        Array{Int64}(undef, sz),
        Array{Int64}(undef, sz),
        Array{Int64}(undef, sz),
        Array{Int64}(undef, sz),
        Array{Float64}(undef, sz[1],sz[2],3))

    MAXFULLSHIPSTODROPINBEGINNING=1
    if NPlayers>2
        MAXFULLSHIPSTODROPINBEGINNING=2
    end

    if gameisending
        shipyardmoreexpensivefactor=1
    elseif NPlayers==2 || (NPlayers>2 && halitemap.sz[1]>=48) || (NPlayers>2 && halitemap.sz[1]<=40 && length(positions.mydroppoints)==1)
        shipyardmoreexpensivefactor=2
    else
        shipyardmoreexpensivefactor=1
    end

    should_gosimple=Int64[]
    Vwantstomine=Int64[]
    Mhpt3 = ones(sz[1],sz[2],Nmyships) .* -Inf
    orderN = s.resorderN
    if any(Vgameisending)
        orderN = sortperm(Vmyshipshalite, rev=true) #with biggest first
    end

    for n in orderN
        should_godropfast = (Vmyshipshalite[n]>500 && filters.mydroppointisnearby[Pmyships[n]] && turn>50) || Vmyshipshalite[n]>=990 || IDmyships[n] in s.IDmyships_full || (Vmyshipshalite[n]>20 && gameisending) || ((filters.Enemyhavemoreshipsclose[Pmyships[n]] || !filters.mydropointiscloser[Pmyships[n]]) && Vmyshipshalite[n]>666 && filters.enemyshipsclose[Pmyships[n]]>2)
        
        #SIMPLE HPT always in some situations
        if gameisending && Vmyshipshalite[n]<=20
            push!(should_gosimple, n)
            push!(Vwantstomine, n)
            continue
        end

        if !gameisending && !should_godropfast && (Minspiredcloseby[Pmyships[n]] || !shouldgenerateship || (Nmyships>13 && filters.hasbighalitesquarecloseby[Pmyships[n]]))            
            push!(should_gosimple, n)
            push!(Vwantstomine, n)
            continue
        end

        p_closestdrop[n] = get_closestdrop(sz, Pmyships[n], Pmydroppointsplus, shipyardmoreexpensivefactor)

        if any(Vgameisending)
            reservedALL[p_closestdrop[n],:] .= false
        end

        ticks2drop_fast[n] = aq.get_mapmetrics!(d[n], mapmetrics[2][n], M, 10000, Mones, Pmyships[n], p_closestdrop[n], Vmyshipshalite[n], MAXFUTURE, reservedALL)
        
        if should_godropfast || (Vmyshipshalite[n]>20 && ticks2drop_fast[n]>(turns_remaining-1))
            #go fast to drop
            s.IDmyships_full = unique([s.IDmyships_full; IDmyships[n]])

            if length(Pmydroppoints)==1 && fullshipsonthewaytonewdropoff >= MAXFULLSHIPSTODROPINBEGINNING
                p_closestdrop_safe = get_closestdrop(sz, Pmyships[n], Pmydroppoints, 1)
                target[n]=p_closestdrop_safe
            else
                target[n]=p_closestdrop[n]
            end
            dir[n] = aq.trackpath!(Pmyships[n], target[n], mapmetrics[2][n], reservedALL, Ma,MAXFUTURE)

            if target[n] in Pdesirednewdropoffs
                fullshipsonthewaytonewdropoff+=1
            end
        else
            #will not go simple and will not go fast to drop.
            if maximum(filters.newestdropbonusmultiplier)>1 #decide conditions for newestdropbonusmultiplier in processing.jl
                ticks2drop_mine[n] = aq.get_mapmetrics!(d[n], mapmetrics[1][n], Ma, thresh_movefaster, filters.newestdropbonusmultiplier, Pmyships[n], p_closestdrop[n], Vmyshipshalite[n], MAXFUTURE, reservedALL)
            else
                #filters.newestdropbonusmultiplier is only 1.
                ticks2drop_mine[n] = aq.get_mapmetrics!(d[n], mapmetrics[1][n], Ma, thresh, filters.newestdropbonusmultiplier, Pmyships[n], p_closestdrop[n], Vmyshipshalite[n], MAXFUTURE, reservedALL)
            end
            
            carryingdrop[n] = mapmetrics[1][n].carrying_aftermined[p_closestdrop[n]]
            if Nmyships<6
                hptb_full[n], cib_full[n]=findmax(mapmetrics[1][n].hpt.*(mapmetrics[1][n].carrying_aftermined.>990))
            end
            hptb[n], cib[n] = findmax(mapmetrics[1][n].hpt)
            if Nmyships<6 && hptb_full[n]>0
                #go mining full
                target[n]=cib_full[n]
                dir[n] = aq.trackpath!(Pmyships[n], target[n], mapmetrics[1][n], reservedALL, Ma,MAXFUTURE)
            elseif !Minspiredcloseby[Pmyships[n]] && ((carryingdrop[n]>930 && Vmyshipshalite[n]>333) || IDmyships[n] in s.IDmyships_minetowardsdrop)
                #mine towards drop.
                s.IDmyships_minetowardsdrop = unique([s.IDmyships_minetowardsdrop; IDmyships[n]])

                target[n]=p_closestdrop[n]
                dir[n] = aq.trackpath!(Pmyships[n], target[n], mapmetrics[1][n], reservedALL, Ma, MAXFUTURE)
            else
                #go mining normal
                target[n]=cib[n]
                dir[n] = aq.trackpath!(Pmyships[n], target[n], mapmetrics[1][n], reservedALL, Ma, MAXFUTURE)
            end
        end

        if target[n] in Pdesirednewdropoffs
            shipsonthewaytonewdropoff += 1
            if shipsonthewaytonewdropoff>div(Nmyships,2)
                Pmydroppointsplus=Pmydroppoints
            end
        end

        
    end

    new_orderN = Int64[]
    for n in orderN
        if !(n in should_gosimple)
            push!(new_orderN, n)
        end
    end

    for n in orderN
        if n in should_gosimple
            p_closestdrop[n] = get_closestdrop(sz, Pmyships[n], Pmydroppointsplus, shipyardmoreexpensivefactor)
            personalized!(filters, shouldgenerateship, personalM, sz, reservedALL,M, filters.goodmultiplier, Pmyships[n], Vmyshipshalite[n], Venemyhipshalite, Penemyships, Minspired,Mmydropointiscloser,MIhavemoreshipsclose,Mmydroppointsnearby,NPlayers,gameisending,MEnemyhavemoreshipsclose,Penemydroppoints, positions, n, vectors, various)
            ticks2drop_fast[n] = aq.get_mapmetrics!(d[n], mapmetrics[2][n], M, 10000, Mones, Pmyships[n], p_closestdrop[n], Vmyshipshalite[n], MAXFUTURE, personalM.preservedALL)
            Mhpt3[:,:,n] = simplehpt(simplehptstruct, personalM.pMa, personalM.pMmultiplier, Vmyshipshalite[n], mapmetrics[2][n].arrivalcost, mapmetrics[2][n].arrivalticks, personalM.preservedALL)
        end
    end

    for n in orderN
        if n in should_gosimple && n in n_cantmove
            push!(new_orderN, n)
            target[n]=Pmyships[n]
            dir[n]=5
            Mhpt3[:,:,n] .= -Inf #remove ship
            if filters.enemyshipsclose[target[n]]==0
                Mhpt3[target[n],:] .= -Inf #remove square
            else
                Mhpt3[target[n],:] = Mhpt3[target[n],:] .* 0.75 #modify square.. not correct to modify hpt but hopefuly same effect as modifying M
            end
        end
    end

    for _=1:length(should_gosimple)
        v, i = findmax(Mhpt3)
        n=i[3] #ship n
        if n in should_gosimple
            if n in n_cantmove
                continue
            end
            push!(new_orderN, n)
            target[n] = CartesianIndex(i[1],i[2])
            dir[n] = aq.trackpath!(Pmyships[n], target[n], mapmetrics[2][n], reservedALL, Ma,MAXFUTURE)

            Mhpt3[:,:,n] .= -Inf #remove ship
            if filters.enemyshipsclose[target[n]]==0
                Mhpt3[target[n],:] .= -Inf #remove square
            else
                Mhpt3[target[n],:] = Mhpt3[target[n],:] .* 0.75 #modify square.. not correct to modify hpt but hopefuly same effect as modifying M
            end
        else
            Mhpt3[:,:,n] .= -Inf #remove ship
        end
    end

    #avoid dropoff gridlocks (put ship first reservation order, not sure if needed anymore)
    hastomovefromdropN = Int64[]
    if !gameisending
        for n in new_orderN
            if Pmyships[n] in Pmydroppoints
                p=Pmyships[n]
                p1=aq.wrap(sz, p+CartesianIndex(1,0))
                p2=aq.wrap(sz, p+CartesianIndex(0,1))
                p3=aq.wrap(sz, p+CartesianIndex(-1,0))
                p4=aq.wrap(sz, p+CartesianIndex(0,-1))
                if (p1 in Pmyships || p1 in Penemyships || (p1 in Penemydroppoints && Menemyshipsnearby[p1])) && (p2 in Pmyships || p2 in Penemyships  || (p2 in Penemydroppoints && Menemyshipsnearby[p2])) && (p3 in Pmyships || p3 in Penemyships  || (p3 in Penemydroppoints && Menemyshipsnearby[p3])) && (p4 in Pmyships || p4 in Penemyships  || (p4 in Penemydroppoints && Menemyshipsnearby[p4]))
                    #ship is surrounded and standing on dropoff
                    push!(hastomovefromdropN, n)
                    #new_orderN = new_orderN[new_orderN .!= n] #remove n
                    #new_orderN = [n; new_orderN] #and add first
                end
            end
        end
    end
    s.resorderN = new_orderN

    #this decides when to stop making new ships, atleast in 2p games
    newshiphastimetobecomefull=true
    if Nmyships>0
        reservedALLunreserved=falses(sz[1],sz[2],MAXFUTURE)
        n=1
        ticks2drop_mine = aq.get_mapmetrics!(d[n], mapmetrics[1][n], Ma, thresh, Mones, positions.myshipyard, positions.myshipyard, 0, MAXFUTURE, reservedALLunreserved)
        newship_hpt_full, newship_ci_full = findmax(mapmetrics[1][n].hpt.*(mapmetrics[1][n].carrying_aftermined.>990))
        newshiptickstobecomefull = mapmetrics[1][n].arrivalticks[newship_ci_full] + mapmetrics[1][n].tickshere[newship_ci_full]
        if newship_hpt_full<=0 || newshiptickstobecomefull*1.5 > (various.turns_remaining-30)
            newshiphastimetobecomefull=false
        end
    end

    shiponthewaytonewdropoff=shipsonthewaytonewdropoff>0

    return dir, target, p_closestdrop, Vwantstomine, shiponthewaytonewdropoff,hastomovefromdropN, fullshipsonthewaytonewdropoff>0, newshiphastimetobecomefull
end

function Mmineamount(M::Array{Int64,2}, Mmultiplier::Array{Int64,2})
    mined = div.(M.+3,4)
    gained = mined .* Mmultiplier
    return mined, gained
end

function simplehpt(ss::Simplehptstruct, Mo::Array{Int64,2}, Mmultiplier::Array{Int64,2}, myshipshalite::Int64, Mcost::Array{Int64,2}, Marrivalticks::Array{Int64,2}, preservedALL::BitArray{3})
    #this function assigns values to squares, (halite per tick) and is used by ships nearby enemies, so it determines 99% of moves in 4p games.
    #the other more advanced axesquadrants() is the normal "solo" mining algorithm. 
    maxmining = 1000-myshipshalite

    sz=size(Mo)
    for x=1:sz[2], y=1:sz[1]
        if Marrivalticks[y,x]==0
            ss.unreservedonarrival[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+1]
            ss.unreservedafterarrival1[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+1]
            ss.unreservedafterarrival2[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+2]
            ss.unreservedafterarrival3[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+3]
        elseif Marrivalticks[y,x]<47
            ss.unreservedonarrival[y,x] = !preservedALL[y,x,Marrivalticks[y,x]]
            ss.unreservedafterarrival1[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+1]
            ss.unreservedafterarrival2[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+2]
            ss.unreservedafterarrival3[y,x] = !preservedALL[y,x,Marrivalticks[y,x]+3]
        else
            ss.unreservedonarrival[y,x] = true
            ss.unreservedafterarrival1[y,x] = true
            ss.unreservedafterarrival2[y,x] = true
            ss.unreservedafterarrival3[y,x] = true
        end
    end
    
    ss.M=copy(Mo)
    ss.m1, ss.g1 = Mmineamount(ss.M.*(ss.unreservedonarrival .& ss.unreservedafterarrival1), Mmultiplier)
    ss.M -= ss.m1
    ss.m2, ss.g2 = Mmineamount(ss.M.*(ss.unreservedonarrival .& ss.unreservedafterarrival1 .& ss.unreservedafterarrival2), Mmultiplier)
    ss.M -= ss.m2
    ss.m3, ss.g3 = Mmineamount(ss.M.*(ss.unreservedonarrival .& ss.unreservedafterarrival1 .& ss.unreservedafterarrival2 .& ss.unreservedafterarrival3), Mmultiplier)

    ss.hpt[:,:,1] = max.(0, (min.(maxmining, ss.g1)) - Mcost) ./ (Marrivalticks.+1)
    ss.hpt[:,:,2] = max.(0, (min.(maxmining, ss.g1+ss.g2)) - Mcost) ./ (Marrivalticks.+2)
    ss.hpt[:,:,3] = max.(0, (min.(maxmining, ss.g1+ss.g2+ss.g3)) - Mcost) ./ (Marrivalticks.+3)

    Mhpt = maximum(ss.hpt, dims=3)
    return Mhpt
end

r2(a) = round(a, digits=2)

function reservenearby!(preservedALL::BitArray{3}, pMmultiplier::Array{Int64,2}, ENEMYFUTURE::Int64, p::CartesianIndex{2}, p1::CartesianIndex{2},p2::CartesianIndex{2},p3::CartesianIndex{2},p4::CartesianIndex{2})
    pMmultiplier[p] = 1
    pMmultiplier[p1] = 1
    pMmultiplier[p2] = 1
    pMmultiplier[p3] = 1
    pMmultiplier[p4] = 1
    for i = 1:ENEMYFUTURE
        preservedALL[p,i] = true
        preservedALL[p1,i] = true
        preservedALL[p2,i] = true
        preservedALL[p3,i] = true
        preservedALL[p4,i] = true
    end
end

function reservep!(preservedALL::BitArray{3}, pMmultiplier::Array{Int64,2}, ENEMYFUTURE::Int64, p::CartesianIndex{2})
    pMmultiplier[p] = 1
    for i = 1:ENEMYFUTURE
        preservedALL[p,i] = true
    end
end

function bonusnearby!(Minspired::BitArray{2}, pMmultiplier::Array{Int64,2}, ENEMYFUTURE::Int64, p::CartesianIndex{2}, p1::CartesianIndex{2},p2::CartesianIndex{2},p3::CartesianIndex{2},p4::CartesianIndex{2})
    if Minspired[p]
        pMmultiplier[p] = 6
    end
    if Minspired[p1]
        pMmultiplier[p1] = 6
    end
    if Minspired[p2]
        pMmultiplier[p2] = 6
    end
    if Minspired[p3]
        pMmultiplier[p3] = 6
    end
    if Minspired[p4]
        pMmultiplier[p4] = 6
    end
    true
end

function unreservenearby!(preservedALL::BitArray{3}, ENEMYFUTURE::Int64, p::CartesianIndex{2}, p1::CartesianIndex{2},p2::CartesianIndex{2},p3::CartesianIndex{2},p4::CartesianIndex{2})
    for i = 1:ENEMYFUTURE
        preservedALL[p,i] = false
        preservedALL[p1,i] = false
        preservedALL[p2,i] = false
        preservedALL[p3,i] = false
        preservedALL[p4,i] = false
    end
end

function personalized!(filters::Filters, shouldgenerateship::Bool, personalM::PersonalM, sz::Tuple{Int64,Int64}, reservedALL::BitArray{3}, M::Array{Int64,2}, Mmultiplier::Array{Int64,2}, p_ship::CartesianIndex{2}, shiphalite::Int64, Venemyhipshalite::Array{Int64,1}, Penemyships::Array{CartesianIndex{2},1}, Minspired::BitArray{2}, Mmydropointiscloser::BitArray{2},MIhavemoreshipsclose::BitArray{2},Mmydroppointsnearby::BitArray{2},NPlayers::Int64,gameisending::Bool,MEnemyhavemoreshipsclose::BitArray{2},Penemydroppoints::Array{CartesianIndex{2},1}, positions::Positions, n::Int64, vectors::Vectors, various::Various)
    personalM.preservedALL = copy(reservedALL)
    personalM.pMa = copy(M)
    personalM.pMmultiplier = copy(Mmultiplier)
    #preservedALL[p_ship,1] = false

    ENEMYFUTURE=50

    #BONUSES
    if NPlayers==2
        for (i,p) in enumerate(Penemyships)
            if shiphalite<100 && Mmydropointiscloser[p] && MIhavemoreshipsclose[p] && shiphalite<Venemyhipshalite[i]
                personalM.pMa[p] += div(Venemyhipshalite[i],5)
            end

            if shiphalite<Venemyhipshalite[i] && MIhavemoreshipsclose[p]
                p1=aq.wrap(sz, p+CartesianIndex(1,0))
                p2=aq.wrap(sz, p+CartesianIndex(0,1))
                p3=aq.wrap(sz, p+CartesianIndex(-1,0))
                p4=aq.wrap(sz, p+CartesianIndex(0,-1))

                bonusnearby!(Minspired, personalM.pMmultiplier, ENEMYFUTURE, p, p1, p2, p3, p4)
            end
        end
    else
        for (i,p) in enumerate(Penemyships)
            if shiphalite<100 && filters.inspired[p] && MIhavemoreshipsclose[p] && shiphalite<Venemyhipshalite[i]
                personalM.pMa[p] += div(Venemyhipshalite[i],5)
            end

            if shiphalite<Venemyhipshalite[i] && MIhavemoreshipsclose[p] && filters.inspired[p]
                p1=aq.wrap(sz, p+CartesianIndex(1,0))
                p2=aq.wrap(sz, p+CartesianIndex(0,1))
                p3=aq.wrap(sz, p+CartesianIndex(-1,0))
                p4=aq.wrap(sz, p+CartesianIndex(0,-1))

                bonusnearby!(Minspired, personalM.pMmultiplier, ENEMYFUTURE, p, p1, p2, p3, p4)
            end
        end
    end

    #AVOID (make the ships not picking a target is has to avoid later anyway)
    #this is supposed to be equal to avoidrules in collisioncheck.jl)
    for (i,p) in enumerate(Penemyships)
        p1=aq.wrap(sz, p+CartesianIndex(1,0))
        p2=aq.wrap(sz, p+CartesianIndex(0,1))
        p3=aq.wrap(sz, p+CartesianIndex(-1,0))
        p4=aq.wrap(sz, p+CartesianIndex(0,-1))


        if !filters.enemyshipisnearby[p]
            #avoidoption[n]=0
            continue
        end
        #assume enemy ship is nearby p now

        if positions.myships[n] in positions.mydroppoints
            #avoidoption[n]=1
            continue
        end

        if p in positions.mydroppoints
            #avoidoption[n]=2
            continue
        end

        if p in positions.enemydroppoints && vectors.myshipshalite[n]>10
            #avoidoption[n]=3
            #return true
            reservep!(personalM.preservedALL, personalM.pMmultiplier, ENEMYFUTURE, p)
            continue
        end

        #if filters.mydroppointisnearby[p] && gameisending
        if gameisending && filters.mydroppointisnearbyr2[p]
            #avoidoption[n]=4
            #return false
            continue
        end

        #if filters.mydroppointisnearby[p] && filters.Ihavemoreshipsclose[p]
        if filters.mydroppointisnearby[p] && filters.Ihavemoreshipsclose_unmodified[p]
            #avoidoption[n]=5
            #return false
            continue
        end

        if gameisending && vectors.myshipshalite[n]<=20
            #avoidoption[n]=6
            #return false
            continue
        end

        if various.NPlayers==2 && filters.Ihavemoreshipsclose[p] && filters.mydropointiscloser[p]
            #return false
            continue
        end

        #if filters.Ihavemoreshipsclose[p] #&& filters.mydropointiscloser[p]
        #if filters.Ihavemoreshipsclose[p] && filters.inspired_future1[p]
        if various.NPlayers>2 && filters.Ihavemoreshipsclose[p] && filters.inspired[p]
            #avoidoption[n]=7
            #return false
            continue
        end

        if vectors.myshipshalite[n] > filters.enemyshipshaliteMINnearby[p]
            #avoidoption[n]=8
            #return true
            reservep!(personalM.preservedALL, personalM.pMmultiplier, ENEMYFUTURE, p)
            continue
        end

        #if filters.Enemyhavemoreshipsclose[p] && p in positions.enemyships
        if filters.Enemyhavemoreshipsclose[p]
            #avoidoption[n]=9
            #return true
            reservep!(personalM.preservedALL, personalM.pMmultiplier, ENEMYFUTURE, p)
            continue
        end


        if various.NPlayers>2 && filters.myshipsclose[p]<=1
            #avoidoption[n]=10
            #return true
            reservep!(personalM.preservedALL, personalM.pMmultiplier, ENEMYFUTURE, p)
            continue
        end

        if various.NPlayers>2 && length(positions.mydroppoints)==1 && various.turn<50
            #avoidoption[n]=11
            #return true
            reservep!(personalM.preservedALL, personalM.pMmultiplier, ENEMYFUTURE, p)
            continue
        else
            #return false
            continue
        end
    end


    p=p_ship
    p1=aq.wrap(sz, p+CartesianIndex(1,0))
    p2=aq.wrap(sz, p+CartesianIndex(0,1))
    p3=aq.wrap(sz, p+CartesianIndex(-1,0))
    p4=aq.wrap(sz, p+CartesianIndex(0,-1))

    if !Minspired[p]; personalM.pMmultiplier[p]=1 end
    if !Minspired[p1]; personalM.pMmultiplier[p1]=1 end
    if !Minspired[p2]; personalM.pMmultiplier[p2]=1 end
    if !Minspired[p3]; personalM.pMmultiplier[p3]=1 end
    if !Minspired[p4]; personalM.pMmultiplier[p4]=1 end

    return true 
end



