function newdropoffs_2p(s::State, various::Various, halitemap::Halitemap, matrices::Matrices, positions::Positions, filters::Filters)
    if length(positions.myships)<13 || various.turns_remaining < 90 || s.ticks_since_created_dropoff<25
        return CartesianIndex{2}[]
    end

    if halitemap.sz[1]==64
        d=31 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1=16 #cld(47-16, 2)
        maxdist1=2*16

        mindist2=16
        maxdist2=2*16
    elseif halitemap.sz[1]==56
        d=27 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1=14 ##cld(41-14, 2) #distance between shipyards divided by 2, rounded up.
        maxdist1=2*14

        mindist2=14
        maxdist2=2*14
    elseif halitemap.sz[1]==48
        d=23 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1=12
        maxdist1=2*12

        mindist2=12
        maxdist2=48

    elseif halitemap.sz[1]==40
        d=17 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 6
        mindist1=9
        maxdist1=40

        mindist2=9
        maxdist2=40
    elseif halitemap.sz[1]==32
        d=15 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 6
        mindist1=8
        maxdist1=32

        mindist2=8
        maxdist2=32
    else
        #what I used to have for all.
        THRESHOLD = 8000
        r = 6
        mindist1=12
        maxdist1 = 17

        mindist2=14
        maxdist2 = 20
    end

    sumnearbyhalite = df.diamondfilter(halitemap.M, r)

    
    if length(positions.mydroppoints)==1
        reasonabledistance = mindist1 .< filters.mhdmydropoints .< maxdist1
        A = sumnearbyhalite .* filters.myshipyardiscloser .* reasonabledistance
    else
        reasonabledistance = mindist2 .< filters.mhdmydropoints .< maxdist2
        A = sumnearbyhalite .* (filters.myshipyardiscloser .| filters.mydropointiscloser .| filters.mhdplayerborder) .* reasonabledistance
    end

    
    #A[positions.enemydroppoints] .= 0
    for p in positions.enemydroppoints
        A[p] .= 0
        A[wrap(halitemap.sz, p+CartesianIndex(1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,1))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(-1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,-1))] = 0
    end
    A[positions.mydroppoints] .= 0
    A[positions.enemyships] .= 0
    
    v,i = findmax(A)

    A[i]=0
    A[wrap(halitemap.sz, i+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,-1))] = 0
    v2,i2 = findmax(A)

    A[i2]=0
    A[wrap(halitemap.sz, i2+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,-1))] = 0
    v3,i3 = findmax(A)

    if sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD && sumnearbyhalite[i3]>THRESHOLD
        return [i,i2,i3]
    elseif sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD
        return [i,i2]
    elseif sumnearbyhalite[i]>THRESHOLD
        return [i]
    else
        return CartesianIndex{2}[]
    end
end


function newdropoffs_4p(s::State, various::Various, halitemap::Halitemap, matrices::Matrices, positions::Positions, filters::Filters)    
    if length(positions.myships)<13 || various.turns_remaining < 90 || s.ticks_since_created_dropoff<25
        return CartesianIndex{2}[]
    end
    #old:
    #1: 12 .< x .<17
    #2: 14 .< x .< 20
    sz=halitemap.sz
    if sz[1]==64
        d=21 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1 = 11 #cld(21,2)
        maxdist1 = 23

        mindist2 = 12
        maxdist2 = 30
        
    elseif sz[1]==56
        d=19 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1 = 10 #cld(19,2)
        maxdist1 = 27

        mindist2 = 11
        #maxdist2 = 2*11
        maxdist2 = 27
    elseif sz[1]==48
        d=19 #distance to enemy shipyard
        THRESHOLD = 8000
        r = 6
        mindist1=10 ##cld(19, 2)
        maxdist1=48

        mindist2=10
        maxdist2 = 48
    elseif sz[1]==40
        d=17 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 6
        mindist1=9 #cld(17, 2)
        maxdist1 = 40

        mindist2=9
        maxdist2 = 40
    elseif sz[1]==32
        d=15 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 6
        mindist1=8 #cld(15, 2)
        maxdist1 = 32

        mindist2=8
        maxdist2 = 32
    else
        #what I used to have for all.
        THRESHOLD = 8000
        r = 6
        mindist1=12
        maxdist1 = 17

        mindist2=14
        maxdist2 = 20
    end

    sumnearbyhalite = df.diamondfilter(halitemap.M, r)
    M_modified = copy(halitemap.M)
    M_modified[positions.enemyships] .= 0
    Minspired_soonprobably = df.diamondfilter(matrices.enemyships, 8).>=2
    sumnearbyhalitemodified = df.diamondfilter(M_modified .+ M_modified.*Minspired_soonprobably , r)

    go_unmodified = (sz[1]>=56 && (length(positions.mydroppoints)==2 || length(positions.mydroppoints)==3)) || (sz[1]==48 && length(positions.mydroppoints)==2)
    if various.NPlayers>2 && go_unmodified
        #second dropoff likely to give inspired anyway atleast on size56 maps. so place it using unmodified
        sumnearbyhalitemodified = sumnearbyhalite
    end

    
    if length(positions.mydroppoints)==1
        reasonabledistance = mindist1 .< filters.mhdmydropoints .< maxdist1 #distance between shipyards divided by 2.
        A = sumnearbyhalitemodified .* filters.myshipyardiscloser .* reasonabledistance
        #A = sumnearbyhalitemodified .* filters.mhdplayerborder
    else
        reasonabledistance = mindist2 .< filters.mhdmydropoints .< maxdist2
        A = sumnearbyhalitemodified .* (filters.myshipyardiscloser .| filters.mydropointiscloser .| filters.mhdplayerborder) .* reasonabledistance
    end

    
    #A[positions.enemydroppoints] .= 0
    for p in positions.enemydroppoints
        A[p] .= 0
        A[wrap(halitemap.sz, p+CartesianIndex(1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,1))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(-1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,-1))] = 0
    end
    A[positions.mydroppoints] .= 0
    A[positions.enemyships] .= 0
    
    v,i = findmax(A)

    A[i]=0
    A[wrap(halitemap.sz, i+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,-1))] = 0
    v2,i2 = findmax(A)

    A[i2]=0
    A[wrap(halitemap.sz, i2+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,-1))] = 0
    v3,i3 = findmax(A)

    if sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD && sumnearbyhalite[i3]>THRESHOLD
        return [i,i2,i3]
    elseif sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD
        return [i,i2]
    elseif sumnearbyhalite[i]>THRESHOLD
        return [i]
    else
        return CartesianIndex{2}[]
    end
end


function newdropoffs_4p_bordersonly_ish(s::State, various::Various, halitemap::Halitemap, matrices::Matrices, positions::Positions, filters::Filters)
    if length(positions.myships)<13 || various.turns_remaining < 90 || s.ticks_since_created_dropoff<25
        return CartesianIndex{2}[]
    end
    #old:
    #1: 12 .< x .<17
    #2: 14 .< x .< 20
    sz=halitemap.sz
    if sz[1]==40
        d=17 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 6
        mindist1=9 #cld(17, 2)
        maxdist1 = 22

        mindist2=8
        maxdist2 = 22
    elseif sz[1]==32
        # 12 5   7   6
        d=15 #distance to enemy shipyard
        THRESHOLD = 9000
        r = 5
        mindist1=7 #cld(15, 2)
        maxdist1 = 16

        mindist2=7
        maxdist2 = 16
    else
        #what I used to have for all.
        THRESHOLD = 8000
        r = 6
        mindist1=12
        maxdist1 = 17

        mindist2=14
        maxdist2 = 20
    end

    sumnearbyhalite = df.diamondfilter(halitemap.M, r)
    
    if length(positions.mydroppoints)==1
        reasonabledistance = mindist1 .< filters.mhdmydropoints .< maxdist1
        #outsidemyarea = (.!filters.myshipyardiscloser)
        #A = sumnearbyhalite .* (filters.mhdplayerborder .| outsidemyarea) .* reasonabledistance
        A = sumnearbyhalite .* filters.mhdplayerborder .* reasonabledistance
    else
        reasonabledistance = mindist2 .< filters.mhdmydropoints .< maxdist2
        #outsidemyarea = (.!filters.myshipyardiscloser)
        #A = sumnearbyhalite .* (filters.mhdplayerborder .| outsidemyarea) .* reasonabledistance
        A = sumnearbyhalite .* filters.mhdplayerborder .* reasonabledistance
    end

    
    #A[positions.enemydroppoints] .= 0
    for p in positions.enemydroppoints
        A[p] .= 0
        A[wrap(halitemap.sz, p+CartesianIndex(1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,1))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(-1,0))] = 0
        A[wrap(halitemap.sz, p+CartesianIndex(0,-1))] = 0
    end
    A[positions.mydroppoints] .= 0
    A[positions.enemyships] .= 0
    
    v,i = findmax(A)

    A[i]=0
    A[wrap(halitemap.sz, i+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i+CartesianIndex(0,-1))] = 0
    v2,i2 = findmax(A)

    A[i2]=0
    A[wrap(halitemap.sz, i2+CartesianIndex(1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,1))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(-1,0))] = 0
    A[wrap(halitemap.sz, i2+CartesianIndex(0,-1))] = 0
    v3,i3 = findmax(A)

    if sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD && sumnearbyhalite[i3]>THRESHOLD
        return [i,i2,i3]
    elseif sumnearbyhalite[i]>THRESHOLD && sumnearbyhalite[i2]>THRESHOLD
        return [i,i2]
    elseif sumnearbyhalite[i]>THRESHOLD
        return [i]
    else
        return CartesianIndex{2}[]
    end
end


function get_Mdesirednewdropoffsnearby(s::State, sz::Tuple{Int64,Int64}, Pdesirednewdropoffs::Array{CartesianIndex{2}}, positions::Positions)
    if length(Pdesirednewdropoffs)==0
        return falses(sz)
    else
        Mdesirednewdropoffsnearby=zeros(Int64, sz)
        Mdesirednewdropoffsnearby[Pdesirednewdropoffs] .= 1
        for p in s.previously_desired_newdrops
            Mdesirednewdropoffsnearby[p] = 1
        end
        Mdesirednewdropoffsnearby = df.diamondfilter(Mdesirednewdropoffsnearby, 1)

        diamondpos=(CartesianIndex(0,0), CartesianIndex(1,0),CartesianIndex(0,1),CartesianIndex(-1,0),CartesianIndex(0,-1))
        for q in positions.enemydroppoints
            for k in diamondpos
                p=wrap(sz, q+k)
                Mdesirednewdropoffsnearby[p]=0
            end
        end

        return Mdesirednewdropoffsnearby.>0
    end
end


function buildnewdropoff!(shiponthewaytonewdropoff::Bool, s::State, positions::Positions, various::Various, vectors::Vectors, halitemap::Halitemap, fullshipsonthewaytonewdropoff::Bool, Mdesirednewdropoffsnearby::BitArray{2})
    Pdesirednewdropoffs = positions.desirednewdropoffs
    myhalite = various.myhalite
    Pmyships = positions.myships
    Vmyshipshalite = vectors.myshipshalite
    M = halitemap.M


    #changes pickeddir to 6 (create dropoff) if we can afford it and it is on the spot we wanted
    available_halite = copy(myhalite)
    waiting_for_halite = false
    willbuild = false
    n_willbuild = -1

    if length(Pdesirednewdropoffs)==0
        return available_halite, waiting_for_halite, n_willbuild
    end
    
    Nships=length(Pmyships)
    for n=1:Nships
        p=Pmyships[n]
        if (Mdesirednewdropoffsnearby[p] && !(p in positions.enemydroppoints) && !(p in positions.mydroppoints)) || M[p]>5000
        #if p in Pdesirednewdropoffs
            constructcost = max(0, 4000 - M[p] - Vmyshipshalite[n])
            if constructcost <= available_halite && !willbuild
                available_halite -= constructcost
                #available_halite = available_halite - (4000-Vmyshipshalite[n])
                willbuild = true
                n_willbuild = n
                s.p_newestdrop = p
                s.previously_desired_newdrops = CartesianIndex{2}[]
                #s.previously_desired_newdrops = s.previously_desired_newdrops .!== p
            else
                waiting_for_halite = true
            end
        end
    end

    if !willbuild
        s.previously_desired_newdrops = Pdesirednewdropoffs
    end

    if willbuild
        s.ticks_since_created_dropoff = 0
    elseif shiponthewaytonewdropoff
        available_halite = available_halite-3000
    end

    #=
    for x=1:halitemap.sz[2], y=1:halitemap.sz[1]
        if Mdesirednewdropoffsnearby[y,x]
            targetlog(s.io, various.turn, CartesianIndex(y,x), [string("Mdesirednewdropoffsnearby<br>")], "00FF00")
        end
    end
    =#

    return available_halite, waiting_for_halite, n_willbuild
end