str2ints(s) = parse.(Int, split(s))
readnlines(io::IO, n::Int) = (readline(io) for _ in 1:n)
parse_xy(x::Int, y::Int) = CartesianIndex(y+1, x+1)

function init(io::IO=Base.stdin)::GameMap
    load_constants(readline(io))

    nr_of_players, my_player_id = parse_num_players_and_id(readline(io))

    players = parse_player.(readnlines(io, nr_of_players))

    cols,rows = parse_map_size(readline(io))
    M = parse_map(readnlines(io, rows))

    #manually remove halite from under shipyards.
    for p in players
        M[p.shipyard] = 0
    end

    return GameMap(my_player_id, M, players)
end


function update_frame!(g::GameMap, io::IO=Base.stdin)
    turn = parse_turnnumber(readline(io))
    for _ in 1:length(g.players)
        player_id = parse(Int, readuntil(io, " "))
        update_player!(g.players[player_id], io)
    end
    update_halite!(g.halite, io)
    return turn
end


parse_player(s::String) = parse_player(str2ints(s))
parse_player(s::Array{Int}) = Player(s[1], parse_xy(s[2], s[3]))
parse_map_size(s) = str2ints(s)
parse_map(S) = Matrix(hcat(str2ints.(S)...)')
parse_turnnumber(s) = parse(Int, s)
parse_num_players_and_id(s) = str2ints(s)


function parse_ship(owner::Int, s::String)
    id, x, y, halite = str2ints(s)
    Ship(owner, id, parse_xy(x, y), halite)
end


function parse_dropoff(owner::Int, s::String)
    id, x, y = str2ints(s)
    DropOff(owner, id, parse_xy(x, y))
end


function update_player!(p::Player, io::IO)
    num_ships, num_dropoffs, p.halite = str2ints(readline(io))
    p.ships = parse_ship.(p.id, readnlines(io, num_ships))
    p.dropoffs = parse_dropoff.(p.id, readnlines(io, num_dropoffs))
    p
end


function update_cell!(halite::AbstractMatrix{Int}, s::String)
    x, y, h = str2ints(s)
    halite[parse_xy(x, y)] = h #recieved changed halite cells use zero indexing
end


function update_halite!(halite::AbstractMatrix{Int}, io::IO)
    n_updated_cells = parse(Int, readline(io))
    update_cell!.((halite,), readnlines(io, n_updated_cells))
    halite
end

function sendcommands(cmds::Vector{String}, io::IO=Base.stdout)
    println(io, join(cmds, " "))
end
