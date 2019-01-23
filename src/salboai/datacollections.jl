mutable struct Positions
    myships::Array{CartesianIndex{2},1}
    enemyships::Array{CartesianIndex{2},1}

    myshipyard::CartesianIndex{2}
    enemyshipyards::Array{CartesianIndex{2},1}

    mydroppoints::Array{CartesianIndex{2},1}
    enemydroppoints::Array{CartesianIndex{2},1}

    desirednewdropoffs::Array{CartesianIndex{2},1}
end

mutable struct Vectors
    myshipshalite::Array{Int64,1}
    enemyshipshalite::Array{Int64,1}
    gameisending::BitArray{1}
end

mutable struct Matrices
    myships::Array{Int64,2}
    enemyships::Array{Int64,2}

    myshipshalite::Array{Int64,2}
    enemyshipshalite::Array{Int64,2}

    mydroppoints::Array{Int64,2}
    enemydroppoints::Array{Int64,2}

    enemyships1::Array{Int64,2}
    enemyships2::Array{Int64,2}
    enemyships3::Array{Int64,2}
end

mutable struct Halitemap
    sz::Tuple{Int64,Int64}
    M::Array{Int64,2}
    leavecost::Array{Int64,2}
end


mutable struct Various
    NPlayers::Int64
    Nmyships::Int64
    IDmyships::Array{Int64,1}
    myhalite::Int64
    turn::Int64
    maxturn::Int64
    turns_remaining::Int64
    MAX_Nenemyships::Int64
end

function datacollections(g::GameMap, turn::Int64, maxturn::Int64)
    M = min.(9999,g.halite) #hack to avoid leavecost>1000 when simulating moves.
    sz = size(M)
    Mleavecost = div.(M, 10)

    

    #SHIPS
    ship_owner = [ship.owner  for (id,player) in g.players for ship in player.ships]
    ship_id = [ship.id        for (id,player) in g.players for ship in player.ships]
    ship_p = [ship.p          for (id,player) in g.players for ship in player.ships]
    ship_halite = [ship.halite for (id,player) in g.players for ship in player.ships]

    #indexes
    my = ship_owner .== g.my_player_id
    enemy = ship_owner .!== g.my_player_id

    #vectors
    IDmyships = ship_id[my]
    Vmyshipshalite = ship_halite[my]
    Venemyhipshalite = ship_halite[enemy]
    Pmyships = ship_p[my]
    Penemyships = ship_p[enemy]

    Pallships = ship_p

    #init matrices
    Mmyships = zeros(Int64, sz)
    Menemyships = zeros(Int64,sz)
    Mallships = zeros(Int64, sz)

    Mmyshipshalite = zeros(Int64, sz)
    Menemyshipshalite = zeros(Int64, sz)
    Mallshipshalite = zeros(Int64, sz)

    #assign values
    Mmyships[Pmyships] .= 1
    Menemyships[Penemyships] .= 1
    Mallships[Pallships] .= 1

    Mmyshipshalite[Pmyships] = ship_halite[my]
    Menemyshipshalite[Penemyships] = ship_halite[enemy]
    Mallshipshalite[Pallships] = ship_halite

    


    #DROPOFFS
    dropoff_owner = [dropoff.owner for (id,player) in g.players for dropoff in player.dropoffs]
    dropoff_id = [dropoff.id       for (id,player) in g.players for dropoff in player.dropoffs]
    dropoff_p = [dropoff.p         for (id,player) in g.players for dropoff in player.dropoffs]

    #indexes
    my = dropoff_owner .== g.my_player_id
    enemy = dropoff_owner .!== g.my_player_id

    #vectors
    Pmydropoffs = dropoff_p[my]
    Penemydropoffs = dropoff_p[enemy]
    Palldropoffs = dropoff_p


    #PLAYERS
    player_id = [player.id for (id,player) in g.players]
    player_halite = [player.halite for (id,player) in g.players]
    player_shipyard = [player.shipyard for (id,player) in g.players]

    NPlayers = length(player_id)

    #index for
    my = player_id .== g.my_player_id
    enemy = player_id .!== g.my_player_id

    #assign values
    myplayerid = player_id[my][1]
    enemyplayerids = player_id[enemy]

    myhalite = player_halite[my][1]
    enemyhalite = player_halite[enemy]

    Pmyshipyard = player_shipyard[my][1]
    Penemyshipyards = player_shipyard[enemy]


    Pmydroppoints = [Pmyshipyard; Pmydropoffs]
    Penemydroppoints = [Penemyshipyards; Penemydropoffs]
    MAX_Nenemyships=length(Penemyships)

    Menemyships1 = zeros(Int64,sz)
    Menemyships2 = zeros(Int64,sz)
    Menemyships3 = zeros(Int64,sz)
    if length(enemyplayerids)>1
        enemy1 = ship_owner .== enemyplayerids[1]
        enemy2 = ship_owner .== enemyplayerids[2]
        enemy3 = ship_owner .== enemyplayerids[3]
        Penemyships1=ship_p[enemy1]
        Penemyships2=ship_p[enemy2]
        Penemyships3=ship_p[enemy3]
        MAX_Nenemyships = max(length(Penemyships1),length(Penemyships2),length(Penemyships3))

        Menemyships1[Penemyships1] .= 1
        Menemyships2[Penemyships2] .= 1
        Menemyships3[Penemyships3] .= 1
    else
        Menemyships1 = Menemyships
    end


    #init matrices
    Mmydroppoints = zeros(Int64, sz)
    Menemydroppoints = zeros(Int64, sz)

    Mmydroppoints[Pmydroppoints] .= 1
    Menemydroppoints[Penemydroppoints] .= 1

    Nmyships = length(Vmyshipshalite)

    #placeholders
    Vgameisending = falses(length(Vmyshipshalite))
    Pdesirednewdropoffs = CartesianIndex{2}[]   

    #Collections:
    halitemap = Halitemap(sz, M, Mleavecost)
    various = Various(NPlayers, Nmyships, IDmyships, myhalite, turn, maxturn, maxturn-turn, MAX_Nenemyships)
    positions = Positions(Pmyships, Penemyships, Pmyshipyard, Penemyshipyards, Pmydroppoints, Penemydroppoints, Pdesirednewdropoffs)
    vectors = Vectors(Vmyshipshalite, Venemyhipshalite, Vgameisending)
    matrices = Matrices(Mmyships, Menemyships, Mmyshipshalite, Menemyshipshalite, Mmydroppoints, Menemydroppoints,Menemyships1,Menemyships2,Menemyships3)

    return halitemap, various, positions, vectors, matrices
end