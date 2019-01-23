module aq

mutable struct Mapmetrics
    tickscenter_aftermined::Int64
    minedcenter_aftermined::Int64
    gainedcenter_aftermined::Int64

    hpt::Array{Float64,2}
    ci_camefrom::Array{CartesianIndex{2},2}
    dirfrom::Array{Int64,2}

    arrivalgained::Array{Int64,2}
    arrivalticks::Array{Int64,2}
    arrivalcost::Array{Int64,2}

    carrying_aftermined::Array{Int64,2}

    tickshere::Array{Int64,2}
    minedhere::Array{Int64,2}
end

mutable struct Dirmetrics
    arrivalticks::Int64
    arrivalgained::Int64
    arrivalcost::Int64

    tickshere_beforemove::Int64
    minedhere_beforemove::Int64
    gainedhere_beforemove::Int64

    tickshere_aftermoved::Int64
    minedhere_aftermoved::Int64
    gainedhere_aftermoved::Int64
end

wrap(sz::Tuple{Int64,Int64}, p::CartesianIndex{2}) = CartesianIndex(mod1(p[1],sz[1]), mod1(p[2],sz[2]))

leavecost(m::Int64) = div(m,10)

function mineamount(m::Int64, carrying::Int64, inspiredmultiplier::Int64)
    mined = min(1000-carrying, div(m+3,4))
    gained = min(1000-carrying, div(m+3,4)*inspiredmultiplier)
    return mined, gained
end

function hptmetric(d::Dirmetrics)
    halitechange = d.arrivalgained + d.gainedhere_aftermoved - d.arrivalcost
    ticks = d.arrivalticks + d.tickshere_aftermoved

    if halitechange>0
        return halitechange/ticks
    else
        return 0.001*halitechange - ticks #fast, but if same ticks go cheap
    end
end

function at_ship!(mapmetrics::Mapmetrics, p_ship::CartesianIndex{2}, om::Int64, Mmultiplier::Array{Int64,2}, shiphalite::Int64, thresh::Int64, reservedALL::BitArray{3}, MAXFUTURE::Int64)
    cir = p_ship
    tickshere_aftermined=0
    minedhere_aftermined=0
    gainedhere_aftermined=0
    m=copy(om)
    carrying=copy(shiphalite)
    while true
        nexttick = tickshere_aftermined+1
        if leavecost(m)>carrying && nexttick<MAXFUTURE && reservedALL[cir,nexttick]
            break
        end
        if leavecost(m)>carrying || (carrying<1000 && m > thresh)
            mined,gained = mineamount(m, carrying, Mmultiplier[cir])
            m -= mined
            tickshere_aftermined += 1
            minedhere_aftermined += mined
            gainedhere_aftermined += gained
            carrying += gained
        else
            break
        end
    end

    #assign mapmetrics
    mapmetrics.tickscenter_aftermined = tickshere_aftermined
    mapmetrics.minedcenter_aftermined=minedhere_aftermined
    mapmetrics.gainedcenter_aftermined

    if gainedhere_aftermined>0
        mapmetrics.hpt[cir] = gainedhere_aftermined/tickshere_aftermined
    else
        #mapmetrics.hpt[cir] = 0
        mapmetrics.hpt[cir] = 0.001*gainedhere_aftermined - tickshere_aftermined
        
    end
    mapmetrics.ci_camefrom[cir]=cir
    mapmetrics.dirfrom[cir]=5

    mapmetrics.arrivalgained[cir] = 0
    mapmetrics.arrivalticks[cir] = 0
    mapmetrics.arrivalcost[cir] = 0

    mapmetrics.tickshere[cir] = tickshere_aftermined
    mapmetrics.minedhere[cir] = minedhere_aftermined
    
    mapmetrics.carrying_aftermined[cir] = gainedhere_aftermined + shiphalite
    true
end

function trymove!(d::Dirmetrics, mapmetrics::Mapmetrics, thresh::Int64, ci::CartesianIndex{2}, om::Int64, cir::CartesianIndex{2}, omr::Int64, shiphalite::Int64, reservedALL::BitArray{3}, MAXFUTURE::Int64, Mmultiplier::Array{Int64,2})
    mr = copy(omr)
    m = copy(om)
    #carrying=copy(ocarrying)
    carrying = mapmetrics.arrivalgained[cir] - mapmetrics.arrivalcost[cir] + shiphalite

    d.tickshere_beforemove = 0
    d.minedhere_beforemove = 0
    d.gainedhere_beforemove = 0

    d.tickshere_aftermoved = 0
    d.minedhere_aftermoved = 0
    d.gainedhere_aftermoved = 0

    #mine on the square cir
    while true
    #for _=1:5
        nexttick = mapmetrics.arrivalticks[cir]+d.tickshere_beforemove+1
        if leavecost(mr)>carrying || (nexttick<MAXFUTURE && reservedALL[ci,nexttick]) || (carrying<1000 && mr > thresh)
            mined,gained = mineamount(mr, carrying,Mmultiplier[cir])
            mr -= mined
            d.tickshere_beforemove += 1
            d.minedhere_beforemove += mined
            d.gainedhere_beforemove += gained
            carrying += gained
        else
            break
        end
    end

    #now move to square ci from cir
    d.arrivalgained = mapmetrics.arrivalgained[cir] + d.gainedhere_beforemove
    d.arrivalticks = mapmetrics.arrivalticks[cir] + d.tickshere_beforemove + 1
    d.arrivalcost =  mapmetrics.arrivalcost[cir] + leavecost(mr)
    carrying -= leavecost(mr)

    #and mine there to be able to calculate hpt if we went to ci from cir
    while true
    #for _=1:5
        nexttick =  d.arrivalticks + d.tickshere_aftermoved + 1
        if nexttick<MAXFUTURE && reservedALL[ci,nexttick]
            break
        end
        if leavecost(m)>carrying || (carrying<1000 && m > thresh)
            mined,gained = mineamount(m, carrying,Mmultiplier[ci])
            m -= mined
            d.tickshere_aftermoved += 1
            d.minedhere_aftermoved += mined
            d.gainedhere_aftermoved += gained
            carrying += gained
        else
            break
        end
    end
    true
end

function set_mapmetrics!(mapmetrics::Mapmetrics, ci::CartesianIndex{2}, cir::CartesianIndex{2}, d::Array{Dirmetrics,1}, i::Int64, shiphalite::Int64)
    mapmetrics.hpt[ci] = hptmetric(d[i])
    mapmetrics.arrivalgained[ci] = d[i].arrivalgained
    mapmetrics.arrivalticks[ci] = d[i].arrivalticks
    mapmetrics.arrivalcost[ci] = d[i].arrivalcost
    mapmetrics.carrying_aftermined[ci] = mapmetrics.arrivalgained[ci] - mapmetrics.arrivalcost[ci] + d[i].gainedhere_aftermoved + shiphalite
    mapmetrics.ci_camefrom[ci] = cir
    mapmetrics.dirfrom[ci]=i 
    mapmetrics.tickshere[ci] = d[i].tickshere_aftermoved
    mapmetrics.minedhere[ci] = d[i].minedhere_aftermoved
end

function get_mapmetrics!(d::Array{Dirmetrics,1}, mapmetrics::Mapmetrics, M::Array{Int64,2}, thresh::Int64, Mmultiplier::Array{Int64,2}, p_ship::CartesianIndex{2}, p_closestdrop::CartesianIndex{2}, shiphalite::Int64, MAXFUTURE::Int64, reservedALL::BitArray{3})
    #simulate what the ship would carry and 'halite gained per turns spent to get there'
    #to every square on the map. The ship stands still on every square until the square has less than threshold,
    #or something else happens like the ship is full or the square is about to be occipied by another of my ships.
    #Directions to simulate are restricted in a breadth first search manner, meaning if a square is south-east,
    #the only moves simulated to get there is stay, south and east.

    sz=size(M)
    aq.at_ship!(mapmetrics, p_ship, M[p_ship], Mmultiplier, shiphalite, thresh,reservedALL,MAXFUTURE)
    i=1
    x=p_ship[2]
    for y=p_ship[1]+1:p_ship[1]+div(sz[1],2)
        ci=wrap(sz, CartesianIndex(y,x))
        m=M[ci]
        cir=wrap(sz, CartesianIndex(y-1,x))
        mr=M[cir]
        
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], cir, M[cir], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        set_mapmetrics!(mapmetrics, ci, cir, d, 1, shiphalite)
    end

    i=2
    y=p_ship[1]
    for x=p_ship[2]+1:p_ship[2]+div(sz[2],2)
        ci=wrap(sz, CartesianIndex(y,x))
        cir=wrap(sz, CartesianIndex(y,x-1))
        
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], cir, M[cir], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        set_mapmetrics!(mapmetrics, ci, cir, d, 2, shiphalite)
    end

    i=3
    x=p_ship[2]
    for y=p_ship[1]-1:-1:p_ship[1]-(div(sz[1],2)-1)
        ci=wrap(sz, CartesianIndex(y,x))
        cir=wrap(sz, CartesianIndex(y+1,x))
        
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], cir, M[cir], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        set_mapmetrics!(mapmetrics, ci, cir, d, 3, shiphalite)
    end

    i=4
    y=p_ship[1]
    for x=p_ship[2]-1:-1:p_ship[2]-(div(sz[2],2)-1)
        ci=wrap(sz, CartesianIndex(y,x))
        cir=wrap(sz, CartesianIndex(y,x+1))
        
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], cir, M[cir], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        set_mapmetrics!(mapmetrics, ci, cir, d, 4, shiphalite)
    end


    prehpt=[0.0, 0.0]
    precir=[CartesianIndex(1,1),CartesianIndex(1,1)]

    I=[1,2]
    for x=p_ship[2]+1:p_ship[2]+div(sz[2],2), y=p_ship[1]+1:p_ship[1]+div(sz[1],2)
        ci=wrap(sz, CartesianIndex(y,x))
        
        i=I[1]
        precir[1]=wrap(sz, CartesianIndex(y-1,x))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[1], M[precir[1]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[1]=aq.hptmetric(d[i])
        
        i=I[2]
        precir[2]=wrap(sz, CartesianIndex(y,x-1))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[2], M[precir[2]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[2]=aq.hptmetric(d[i])
        if prehpt[1]>prehpt[2]
            set_mapmetrics!(mapmetrics, ci, precir[1], d, I[1], shiphalite)
        else
            set_mapmetrics!(mapmetrics, ci, precir[2], d, I[2], shiphalite)
        end
        
    end

    I=[2,3]
    for x=p_ship[2]+1:p_ship[2]+div(sz[2],2), y=p_ship[1]-1:-1:p_ship[1]-(div(sz[1],2)-1)
        ci=wrap(sz, CartesianIndex(y,x))
        
        i=I[1]
        precir[1]=wrap(sz, CartesianIndex(y,x-1))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[1], M[precir[1]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[1]=aq.hptmetric(d[i])
        
        i=I[2]
        precir[2]=wrap(sz, CartesianIndex(y+1,x))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[2], M[precir[2]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[2]=aq.hptmetric(d[i])
        if prehpt[1]>prehpt[2]
            set_mapmetrics!(mapmetrics, ci, precir[1], d, I[1], shiphalite)
        else
            set_mapmetrics!(mapmetrics, ci, precir[2], d, I[2], shiphalite)
        end
    end

    I=[3,4]
    for x=p_ship[2]-1:-1:p_ship[2]-(div(sz[2],2)-1), y=p_ship[1]-1:-1:p_ship[1]-(div(sz[1],2)-1)
        ci=wrap(sz, CartesianIndex(y,x))
        
        i=I[1]
        precir[1]=wrap(sz, CartesianIndex(y+1,x))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[1], M[precir[1]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[1]=aq.hptmetric(d[i])
        
        i=I[2]
        precir[2]=wrap(sz, CartesianIndex(y,x+1))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[2], M[precir[2]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[2]=aq.hptmetric(d[i])
        if prehpt[1]>prehpt[2]
            set_mapmetrics!(mapmetrics, ci, precir[1], d, I[1], shiphalite)
        else
            set_mapmetrics!(mapmetrics, ci, precir[2], d, I[2], shiphalite)
        end
    end

    I=[4,1]
    for x=p_ship[2]-1:-1:p_ship[2]-(div(sz[2],2)-1), y=p_ship[1]+1:p_ship[1]+div(sz[1],2)
        ci=wrap(sz, CartesianIndex(y,x))
        
        i=I[1]
        precir[1]=wrap(sz, CartesianIndex(y,x+1))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[1], M[precir[1]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[1]=aq.hptmetric(d[i])
        
        i=I[2]
        precir[2]=wrap(sz, CartesianIndex(y-1,x))
        aq.trymove!(d[i], mapmetrics, thresh, ci, M[ci], precir[2], M[precir[2]], shiphalite, reservedALL, MAXFUTURE, Mmultiplier)
        prehpt[2]=aq.hptmetric(d[i])
        if prehpt[1]>prehpt[2]
            set_mapmetrics!(mapmetrics, ci, precir[1], d, I[1], shiphalite)
        else
            set_mapmetrics!(mapmetrics, ci, precir[2], d, I[2], shiphalite)
        end
    end

    return mapmetrics.arrivalticks[p_closestdrop]
end


function trackpath!(p_ship::CartesianIndex{2}, target::CartesianIndex{2}, mapmetrics::Mapmetrics, reservedALL::BitArray{3}, Ma::Array{Int64,2}, MAXFUTURE::Int64)
    #follow path backwards from target to find out what first direction is
    #modify halite along the way and reserve where the ship is at that timestep in the future.
    ci=target
    dir=5
    if target == p_ship && mapmetrics.tickscenter_aftermined>0
        reservedALL[p_ship,1:mapmetrics.tickscenter_aftermined] .= true
        Ma[p_ship] = max(0, Ma[p_ship]-mapmetrics.minedcenter_aftermined)
    else
        at=0
        while ci != p_ship
            if mapmetrics.arrivalticks[ci]+mapmetrics.tickshere[ci]<MAXFUTURE
                reservedALL[ci,mapmetrics.arrivalticks[ci]:mapmetrics.arrivalticks[ci]+mapmetrics.tickshere[ci]] .= true
                Ma[ci] = max(0, Ma[ci]-mapmetrics.minedhere[ci])
            end

            at = mapmetrics.arrivalticks[ci]
            dir=mapmetrics.dirfrom[ci]

            ci = mapmetrics.ci_camefrom[ci]
        end
        if at>1
            reservedALL[p_ship,1:at-1] .= true
            Ma[p_ship] = max(0, Ma[p_ship]-mapmetrics.minedcenter_aftermined)
            dir=5
        end
    end
    return dir
end

end