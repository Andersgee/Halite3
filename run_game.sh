#!/bin/bash

mkdir -p replays
REPLAYDIR="--replay-directory replays/"

SEED="--seed 56730"
MAP_SIZE="32"

BOTS=()
BOTS+=("julia --project ./MyBot.jl")
#BOTS+=("julia --project ./MyBot.jl")
#BOTS+=("julia --project ./MyBot.jl")
#BOTS+=("julia --project ./MyBot.jl")

./halite-linux -vvv --no-timeout $REPLAYDIR $SEED --width $MAP_SIZE --height $MAP_SIZE "${BOTS[@]}"
