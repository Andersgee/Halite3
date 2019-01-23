function dirΔ(d)
    d == 1 && return CartesianIndex(1, 0)
    d == 2 && return CartesianIndex(0, 1)
    d == 3 && return CartesianIndex(-1, 0)
    d == 4 && return CartesianIndex(0, -1)
    d == 5 && return CartesianIndex(0, 0)
    d == 6 && return CartesianIndex(0, 0)
    return CartesianIndex(0, 0)
end

wrap(sz, p::CartesianIndex) = CartesianIndex(mod1(p[1],sz[1]), mod1(p[2],sz[2]))

function avoidrules(various, positions, vectors, matrices, filters, n, p, gameisending, avoidoption)
    if !filters.enemyshipisnearby[p]
        #avoidoption[n]=0
        return false
    end
    #assume enemy ship is nearby p now

    if positions.myships[n] in positions.mydroppoints
        avoidoption[n]=1
        return false
    end

    if p in positions.mydroppoints
        avoidoption[n]=2
        return false
    end
    
    if p in positions.enemydroppoints && vectors.myshipshalite[n]>10
        avoidoption[n]=3
        return true
    end

    #if filters.mydroppointisnearby[p] && gameisending
    if gameisending && filters.mydroppointisnearbyr2[p]
        avoidoption[n]=4
        return false
    end

    #if filters.mydroppointisnearby[p] && filters.Ihavemoreshipsclose[p]
    if filters.mydroppointisnearby[p] && filters.Ihavemoreshipsclose_unmodified[p]
        avoidoption[n]=5
        return false
    end

    if gameisending && vectors.myshipshalite[n]<=20
        avoidoption[n]=6
        return false
    end

    if various.NPlayers==2 && filters.Ihavemoreshipsclose[p] && filters.mydropointiscloser[p]
        return false
    end

    #if filters.Ihavemoreshipsclose[p] #&& filters.mydropointiscloser[p]
    #if filters.Ihavemoreshipsclose[p] && filters.inspired_future1[p]
    if various.NPlayers>2 && filters.Ihavemoreshipsclose[p] && filters.inspired[p]
        avoidoption[n]=7
        return false
    end

    if vectors.myshipshalite[n] > filters.enemyshipshaliteMINnearby[p]
        avoidoption[n]=8
        return true
    end

    #if filters.Enemyhavemoreshipsclose[p] && p in positions.enemyships
    if filters.Enemyhavemoreshipsclose[p]
        avoidoption[n]=9
        return true
    end


    if various.NPlayers>2 && filters.myshipsclose[p]<=1
        avoidoption[n]=10
        return true
    end
    
    if various.NPlayers>2 && length(positions.mydroppoints)==1 && various.turn<50
        avoidoption[n]=11
        return true
    else
        return false
    end
end

function collisioncheck(dirs::Array{Array{Int64,1},1}, s::State, matrices::Matrices, filters::Filters, various::Various, positions::Positions, vectors::Vectors, halitemap::Halitemap, Vwantstomine::Array{Int64,1}, hastomovefromdropN::Array{Int64,1}, n_willbuild::Int64, Mdesirednewdropoffsnearby::BitArray{2})
    gameisending = any(vectors.gameisending)
    sz=size(halitemap.M)
    Nmyships = length(positions.myships)
    pickeddir=ones(Int64, Nmyships)*9
    avoidoption=zeros(Int64, Nmyships)

    unoccupiedshipyard = true

    #occupied = falses(sz)
    freezeoccupied = falses(sz)


    freezed_something = true
    iter=0
    MAXiter=10
    n_frozen = Int64[]

    while freezed_something && iter < MAXiter
        iter += 1
        freezed_something = false
        pickeddir[:] .= 9
        #avoidoption[:] .= 0

        occupied = falses(sz)

        if various.turn<6
            occupied[positions.myshipyard] = true
        end
        
        for p in positions.enemydroppoints
            if filters.enemyshipisnearby[p]
                occupied[p] = true
            end
        end
        
        #These ships simply have to stay still. Make sure the collision check below dont modify these.
        for n = 1:Nmyships
            if n==n_willbuild
                pickeddir[n] = 6
            elseif halitemap.leavecost[positions.myships[n]] > vectors.myshipshalite[n] || n in n_frozen
                p = positions.myships[n]
                occupied[p] = true
                pickeddir[n] = 5
            end
        end

        
        orderN = s.resorderN
        if gameisending
            orderN = sortperm(vectors.myshipshalite, rev=true) #with biggest first
        end

        #make room on top of dropoffs
        if !gameisending
            for n in orderN
                if n in hastomovefromdropN || (positions.myships[n] == positions.myshipyard && various.turn < 6)
                    OK = false
                    for dir in dirs[n]
                        if dir==5
                            continue
                        end
                        p = positions.myships[n] + dirΔ(dir)
                        p = wrap(sz, p)
                        if !occupied[p]
                            pickeddir[n] = dir
                            occupied[p] = true
                            OK = true
                            break
                        end
                    end

                    if !OK
                        p = positions.myships[n]
                        pickeddir[n] = 5
                        occupied[p] = true
                        freezed_something = true
                        push!(n_frozen, n)
                    end
                end
            end
        end
        
        n_avoidall5options = Int64[]
        for n in orderN
            if gameisending
                occupied[positions.mydroppoints] .= false
            end

            #do this loop only for ships that didnt get a picked direction yet.
            if pickeddir[n] == 9
                OK = false
                avoidlist=falses(5)
                for (i,dir) in enumerate(dirs[n])
                    p = wrap(sz, positions.myships[n]+dirΔ(dir))

                    #dont move back and forth if waiting for a dropoff to be built.
                    #if occupied[p] && p in positions.desirednewdropoffs && !filters.enemyshipisnearby[p]
                    #    #break to freeze ship.
                    #    break
                    #end
                    #if !filters.enemyshipisnearby[p] && p in positions.desirednewdropoffs
                    #if !filters.enemyshipisnearby[positions.myships[n]] && Mdesirednewdropoffsnearby[positions.myships[n]] && n_willbuild>=0
                    #    #break to freeze ship.
                    #    break
                    #end

                    #avoid = false
                    #if !(n in Vwantstomine)
                    avoid = occupied[p] || avoidrules(various, positions, vectors, matrices, filters, n, p, gameisending, avoidoption)
                    avoidlist[i] = avoid
                    #end
                    
                    if !avoid #&& !(vectors.myshipshalite[n]<20 && p in positions.mydroppoints)
                    #if !occupied[p]
                        pickeddir[n] = dir
                        occupied[p] = true
                        OK = true
                        break
                    end
                end

                if !OK && all(avoidlist)
                    push!(n_avoidall5options, n)
                elseif !OK
                    p = positions.myships[n]
                    pickeddir[n] = 5
                    occupied[p] = true
                    freezed_something = true
                    push!(n_frozen, n)
                end
            end
        end

        order_biggest_avoids_first = sortperm(vectors.myshipshalite[n_avoidall5options], rev=true)
        for n in n_avoidall5options[order_biggest_avoids_first]
            OK = false
            for (i,dir) in enumerate(dirs[n])
                if dir==5
                    #use this as last resort freeze
                    continue
                end
                p =  wrap(sz, positions.myships[n]+dirΔ(dir))
                free_ish = !(p in positions.enemyships) && !occupied[p]
                if free_ish
                    pickeddir[n] = dirs[n][i]
                    occupied[p] = true
                    OK = true
                end
            end

            if !OK
                p = positions.myships[n]
                pickeddir[n] = 5
                occupied[p] = true
                freezed_something = true
                push!(n_frozen, n)
            end
        end

        if various.turn<6
            occupied[positions.myshipyard] = false
        end
        unoccupiedshipyard = occupied[positions.mydroppoints[1]] ? false : true
    end

    #=
    for n=1:Nmyships
        shiplog(s.io, various.turn, positions.myships[n], [string("avoidoption: ", avoidoption[n], "<br>")])
    end
    =#

    return pickeddir, unoccupiedshipyard
end