mutable struct Ship
    owner::Int
    id::Int
    p::CartesianIndex{2}
    halite::Int
end


struct DropOff
    owner::Int
    id::Int
    p::CartesianIndex{2}
end


mutable struct Player
    id::Int
    shipyard::CartesianIndex{2}
    halite::Int
    ships::Vector{Ship}
    dropoffs::Vector{DropOff}
end


struct GameMap
    my_player_id::Int
    halite::Matrix{Int}
    players::Dict{Int,Player}
end

Player(id::Int, shipyard_position::CartesianIndex) = Player(id, shipyard_position, 0, Ship[], DropOff[])
GameMap(my_player_id, halite::Matrix{Int}, players::Vector{Player}) = GameMap(my_player_id, halite, Dict(p.id => p for p in players))
me(g::GameMap) = g.players[g.my_player_id]
Base.copy(s::Ship) = Ship(s.owner, s.id, CartesianIndex(s.p), s.halite)

dropoffs_p(p::Player) = [p.shipyard; [d.p for d in p.dropoffs]]
