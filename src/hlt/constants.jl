SHIP_COST = nothing
DROPOFF_COST = nothing
MAX_HALITE = nothing
MAX_TURNS = nothing
EXTRACT_RATIO = nothing
MOVE_COST_RATIO = nothing
INSPIRATION_ENABLED = nothing
INSPIRATION_RADIUS = nothing
INSPIRATION_SHIP_COUNT = nothing
INSPIRED_EXTRACT_RATIO = nothing
INSPIRED_BONUS_MULTIPLIER = nothing
INSPIRED_MOVE_COST_RATIO = nothing


function setdefaultconstants()
    load_constants("""{"CAPTURE_ENABLED":false,"CAPTURE_RADIUS":3,"DEFAULT_MAP_HEIGHT":32,"DEFAULT_MAP_WIDTH":32,"DROPOFF_COST":4000,"DROPOFF_PENALTY_RATIO":4,"EXTRACT_RATIO":4,"FACTOR_EXP_1":2.0,"FACTOR_EXP_2":2.0,"INITIAL_ENERGY":5000,"INSPIRATION_ENABLED":true,"INSPIRATION_RADIUS":4,"INSPIRATION_SHIP_COUNT":2,"INSPIRED_BONUS_MULTIPLIER":2.0,"INSPIRED_EXTRACT_RATIO":4,"INSPIRED_MOVE_COST_RATIO":10,"MAX_CELL_PRODUCTION":1000,"MAX_ENERGY":1000,"MAX_PLAYERS":16,"MAX_TURNS":400,"MAX_TURN_THRESHOLD":64,"MIN_CELL_PRODUCTION":900,"MIN_TURNS":400,"MIN_TURN_THRESHOLD":32,"MOVE_COST_RATIO":10,"NEW_ENTITY_ENERGY_COST":1000,"PERSISTENCE":0.7,"SHIPS_ABOVE_FOR_CAPTURE":3,"STRICT_ERRORS":false,"game_seed":1539853891}""")
end


function parseboolorint(s::AbstractString)
    v = tryparse(Int, s)
    if v != nothing return v end

    v = tryparse(Float64, s)
    if v != nothing return v end

    if s == "false" return false end
    if s == "true" return true end

    error("unknown value \"$s\"")
end


function load_constants(constants::String)
    constants = constants[2:end-1] # skip { and }
    c = split(constants, ',')
    d = Dict(k[2:end-1] => parseboolorint(v) for (k,v) in split.(c, ':'))
    load_constants(d)
end


function load_constants(constants::Dict)
    global SHIP_COST, DROPOFF_COST, MAX_HALITE, MAX_TURNS
    global EXTRACT_RATIO, MOVE_COST_RATIO
    global INSPIRATION_ENABLED, INSPIRATION_RADIUS, INSPIRATION_SHIP_COUNT
    global INSPIRED_EXTRACT_RATIO, INSPIRED_BONUS_MULTIPLIER, INSPIRED_MOVE_COST_RATIO

    """The cost to build a single ship."""
    SHIP_COST = constants["NEW_ENTITY_ENERGY_COST"]

    """The cost to build a dropoff."""
    DROPOFF_COST = constants["DROPOFF_COST"]

    """The maximum amount of halite a ship can carry."""
    MAX_HALITE = constants["MAX_ENERGY"]

    """
    The maximum number of turns a game can last. This reflects the fact
    that smaller maps play for fewer turns.
    """
    MAX_TURNS = constants["MAX_TURNS"]

    """1/EXTRACT_RATIO halite (truncated) is collected from a square per turn."""
    EXTRACT_RATIO = constants["EXTRACT_RATIO"]

    """1/MOVE_COST_RATIO halite (truncated) is needed to move off a cell."""
    MOVE_COST_RATIO = constants["MOVE_COST_RATIO"]

    """Whether inspiration is enabled."""
    INSPIRATION_ENABLED = constants["INSPIRATION_ENABLED"]

    """
    A ship is inspired if at least INSPIRATION_SHIP_COUNT opponent
    ships are within this Manhattan distance.
    """
    INSPIRATION_RADIUS = constants["INSPIRATION_RADIUS"]

    """
    A ship is inspired if at least this many opponent ships are within
    INSPIRATION_RADIUS distance.
    """
    INSPIRATION_SHIP_COUNT = constants["INSPIRATION_SHIP_COUNT"]

    """An inspired ship mines 1/X halite from a cell per turn instead."""
    INSPIRED_EXTRACT_RATIO = constants["INSPIRED_EXTRACT_RATIO"]

    """An inspired ship that removes Y halite from a cell collects X*Y additional halite."""
    INSPIRED_BONUS_MULTIPLIER = constants["INSPIRED_BONUS_MULTIPLIER"]

    """An inspired ship instead spends 1/X% halite to move."""
    INSPIRED_MOVE_COST_RATIO = constants["INSPIRED_MOVE_COST_RATIO"]

    nothing
end
