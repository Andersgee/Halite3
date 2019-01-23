mutable struct State
    io::IO
    IDmyships_full::Vector{Int64}
    IDmyships_minetowardsdrop::Vector{Int64}
    IDmyships_godropblock::Vector{Int64}
    IDalreadyset_threshindex::Dict{Int64,Int64}

    ticks_since_created_dropoff::Int64
    sumhalite_tick1::Int64
    medianquartile25::Int64
    medianquartile33::Int64
    medianquartile50::Int64
    assets_lasttick::Int64
    assestchange_ema::Float64 #
    previous_reservationorder::Vector{Int}
    reservationorder::Vector{Int}
    resorderN::Vector{Int}
    satisfiedfraction::Float64
    reservestage::Int64
    gamestage::Int64
    MAXFUTURE_modifyhalite::Int64
    wentfullfrac::Float64
    p_newestdrop::CartesianIndex{2}
    M_tick1::Array{Int64,2}
    previously_desired_newdrops::Array{CartesianIndex{2},1}
    #add more here
end

startstate(g) = State(IOBuffer(), [], [], [], Dict(-1=>0), 0, sum(g.halite), medianquartile(g.halite, 0.25) ,medianquartile(g.halite, 0.333), medianquartile(g.halite, 0.5), 5000, 0.0, [],[],[], 1.0, 0, 0, 50, 0.0, CartesianIndex(1,1), g.halite, CartesianIndex{2}[])

medianquartile(M, q) = M[sortperm(M[:])][round(Int, prod(size(M))*q)] #for example q=0.25

wrap(sz::Tuple{Int64,Int64}, p::CartesianIndex{2}) = CartesianIndex(mod1(p[1],sz[1]), mod1(p[2],sz[2]))

function update_state!(s::State, various::Various, vectors::Vectors, positions::Positions, halitemap::Halitemap)

    IDmyships = various.IDmyships
    Pmyships = positions.myships


    gameisending = any(vectors.gameisending)
    s.ticks_since_created_dropoff += 1

    Nships = length(IDmyships)

    #=
    for n=1:Nships
        if vectors.myshipshalite[n]>990
            #add ship first in reservationorder if full.
            s.reservationorder = s.reservationorder[s.reservationorder .!= IDmyships[n]]
            s.reservationorder = [IDmyships[n]; s.reservationorder]
        end
    end
    =#

    for n=1:Nships
        #remove ship from list of full ship if on top of dropoff (they are added in hptpath)
        if Pmyships[n] in positions.mydroppoints
            s.IDmyships_full = s.IDmyships_full[s.IDmyships_full .!= IDmyships[n]]
            s.IDmyships_minetowardsdrop = s.IDmyships_minetowardsdrop[s.IDmyships_minetowardsdrop .!= IDmyships[n]]

            #remove ship
            s.reservationorder = s.reservationorder[s.reservationorder .!= IDmyships[n]]
            s.reservationorder = [s.reservationorder; IDmyships[n]]  #add back LAST
        end
    end

    #put ship FIRST in reservationorder if on dropoff and surrounded
    if !gameisending && various.turn>=10 #this is supposed to be the opposite of the "clear dropoffs" conditions inside collisioncheck. its important in the beggining to not change resorder
        for (n,p) in enumerate(Pmyships)
            p1 = wrap(halitemap.sz, p+CartesianIndex(1,0))
            p2 = wrap(halitemap.sz, p+CartesianIndex(0,1))
            p3 = wrap(halitemap.sz, p+CartesianIndex(-1,0))
            p4 = wrap(halitemap.sz, p+CartesianIndex(0,-1))

            if (p in positions.mydroppoints) && (p1 in Pmyships) && (p2 in Pmyships) && (p3 in Pmyships) && (p4 in Pmyships)
                s.reservationorder = s.reservationorder[s.reservationorder .!= IDmyships[n]]
                s.reservationorder = [IDmyships[n]; s.reservationorder]
            end
        end
    end

    #remove dead ships
    for id = s.reservationorder
        if !(id in IDmyships)
            s.reservationorder = s.reservationorder[s.reservationorder .!= id]
        end
    end


    if length(IDmyships) != length(s.reservationorder) #this garbage stuff becuase it doesnt work with warmup oterhwise.. reservationorder is empty when jumping straght to turn 200 or whatever..
        s.resorderN = collect(1:length(IDmyships))
    else
        s.resorderN = [findfirst(IDmyships .== s.reservationorder[i]) for i=1:length(IDmyships)] #use this vector with: "for n in s.resorderN" instead of "n=1:Nships"
    end

    
    for n in s.resorderN
        if vectors.myshipshalite[n]>990
            #add ship first in resorderN if full.
            s.resorderN = s.resorderN[s.resorderN .!= n]
            s.resorderN = [n; s.resorderN]
        end
    end

    true
end
