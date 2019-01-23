function delta(sz, a, b)
    half = div.(sz, 2)
    return mod.(b .- a .+ half, sz) .- half
end
delta(sz, a::CartesianIndex{2}, b::CartesianIndex{2}) = delta(sz, Tuple(a), Tuple(b))

function simpledirs(d, ship_p::CartesianIndex{2}, target::CartesianIndex{2}, closestdrop_p::CartesianIndex{2}, sz, wantstomine, shiphalite::Int64, positions::Positions, desirednewdropoffsnearby::Bool)
    #makes 5 dirs from one.

    t = delta(sz, ship_p, target)
    # example t = (-1, -2)
    y=t[1]
    x=t[2]


    if (ship_p in positions.mydroppoints) #|| shiphalite>990
        #absolutely dont prefer staystill
        d == 1 && x == 0 && return [1,2,4,3,5]
        d == 1 && x > 0 &&  return [1,2,4,3,5]
        d == 1 && x < 0 &&  return [1,4,2,3,5]

        d == 2 && y == 0 && return [2,3,1,4,5]
        d == 2 && y > 0 &&  return [2,1,3,4,5]
        d == 2 && y < 0 &&  return [2,3,1,4,5]
        
        d == 3 && x == 0 && return [3,4,2,1,5]
        d == 3 && x > 0 && return [3,2,4,1,5]
        d == 3 && x < 0 && return [3,4,2,1,5]

        d == 4 && y == 0 && return [4,1,3,2,5]
        d == 4 && y > 0 && return [4,1,3,2,5]
        d == 4 && y < 0 && return [4,3,1,2,5]

        d == 5 && return [5,1,2,3,4]
    elseif wantstomine || desirednewdropoffsnearby
        #prefer stay still as second option, less back n forth?
        #at the moment; wantstomine menas that ship did simplehpt which is "in the action"
        d == 1 && x == 0 && return [1,5,2,4,3]
        d == 1 && x > 0 &&  return [1,5,2,4,3]
        d == 1 && x < 0 &&  return [1,5,4,2,3]

        d == 2 && y == 0 && return [2,5,3,1,4]
        d == 2 && y > 0 &&  return [2,5,1,3,4]
        d == 2 && y < 0 &&  return [2,5,3,1,4]
        
        d == 3 && x == 0 && return [3,5,4,2,1]
        d == 3 && x > 0 && return [3,5,2,4,1]
        d == 3 && x < 0 && return [3,5,4,2,1]

        d == 4 && y == 0 && return [4,5,1,3,2]
        d == 4 && y > 0 && return [4,5,1,3,2]
        d == 4 && y < 0 && return [4,5,3,1,2]
    else
        d == 1 && x == 0 && return [1,2,4,5,3]
        d == 1 && x > 0 &&  return [1,2,5,4,3]
        d == 1 && x < 0 &&  return [1,4,5,2,3]

        d == 2 && y == 0 && return [2,3,1,5,4]
        d == 2 && y > 0 &&  return [2,1,5,3,4]
        d == 2 && y < 0 &&  return [2,3,5,1,4]
        
        d == 3 && x == 0 && return [3,4,2,5,1]
        d == 3 && x > 0 && return [3,2,5,4,1]
        d == 3 && x < 0 && return [3,4,5,2,1]

        d == 4 && y == 0 && return [4,1,3,5,2]
        d == 4 && y > 0 && return [4,1,5,3,2]
        d == 4 && y < 0 && return [4,3,5,1,2]
    end

    if d==5 && ship_p==target
        #this will make it so that we "avoid enemies towards my closest drop" if ship wants to stay where it is but is not allowed
        #but otherwise just "avoid towards intended target" like usual
        t = delta(sz, ship_p, closestdrop_p)
        y=t[1]
        x=t[2]
    end

    d == 5 && y > 0 && x == 0 && return [5,1,2,4,3]
    d == 5 && y == 0 && x > 0 && return [5,2,3,1,4]
    d == 5 && y < 0 && x == 0 && return [5,3,4,2,1]
    d == 5 && y == 0 && x < 0 && return [5,4,1,3,2]

    d == 5 && y > 0 && x > 0 && x>y && return [5,2,1,3,4]
    d == 5 && y > 0 && x > 0 && x<y && return [5,1,2,4,3]

    d == 5 && y < 0 && x > 0 && x>-y && return [5,2,3,1,4]
    d == 5 && y < 0 && x > 0 && x<-y && return [5,3,2,4,1]

    d == 5 && y < 0 && x < 0 && -x<-y && return [5,3,4,2,1]
    d == 5 && y < 0 && x < 0 && -x>-y && return [5,4,3,1,2]

    d == 5 && y > 0 && x < 0 && -x>y && return [5,4,1,3,2]
    d == 5 && y > 0 && x < 0 && -x<y && return [5,1,4,2,3]

    #I dont want this case to happen:
    d == 5 && y == 0 && x == 0 && return [5,1,2,3,4]
    return [5,1,2,3,4]
end


function dir2dirs(dir::Array{Int64,1}, target::Array{CartesianIndex{2},1}, p_closestdrop::Array{CartesianIndex{2},1}, Vwantstomine::Array{Int64,1}, positions::Positions, vectors::Vectors, halitemap::Halitemap, Mdesirednewdropoffsnearby::BitArray{2})
    Pmyships = positions.myships
    sz = halitemap.sz
    Vgameisending = vectors.gameisending

    Nmyships = length(Pmyships)
    
    #dirs=Vector{Vector{Int}}(undef, Nmyships)
    dirs = Array{Array{Int64,1},1}(undef, Nmyships)
    for n=1:Nmyships
        wantstomine = n in Vwantstomine
        shiphalite=vectors.myshipshalite[n]
        desirednewdropoffsnearby = Mdesirednewdropoffsnearby[Pmyships[n]]
        dirs[n] = simpledirs(dir[n], Pmyships[n], target[n], p_closestdrop[n], sz, wantstomine, shiphalite, positions, desirednewdropoffsnearby)
    end
    return dirs
end

