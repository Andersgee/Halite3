module Halite3

include("hlt/constants.jl")
include("hlt/game_map.jl")
include("hlt/networking.jl")
include("hlt/commands.jl")

#include("salboai/flogging.jl")
include("salboai/datacollections.jl")
include("salboai/gamestate.jl")
include("salboai/tick.jl")
include("salboai/processing.jl")
include("salboai/dropoffplacements.jl")
include("salboai/dummymap.jl")
include("salboai/pathfinding.jl")
include("salboai/simpledirs.jl")
include("salboai/collisioncheck.jl")

precompile(warmup, (Int64,))

end
