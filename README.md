# Halite3
My bot for the Halite 3 AI Programming Challenge

<a href="https://halite.io/">Halite</a> is a programming competition created by Two Sigma. In short: Every participant creates a bot that plays a game against other bots. My bot has to beat bots written by other people. <a href="https://halite.io/play/?game_id=5002035">Here</a> and <a href="https://halite.io/play/?game_id=4946734">here</a> is examples of what games might look like. 

Many people invest much time in the competition, and when its over most of us are curious to know what others did differently in order to beat us. This year my bot is in the top5 and so I will share the main ideas behind my bots success.

# Post Mortem
The stucture of the bot is well captured by src/salboai/tick.jl, I will use the layout of this function as headings.

#### 1. datacollections
massage the starter kit objects into something I liked working with more
#### 2. newdropoffs
My idea for placing dropoffs is quite simple. Look at the map, find the best places (most halite within a diamond of radius 6), remove places that already has one of my dropoffs near it, treat the best places as if I already have a dropoff there.
Later, if a ship happen to be standing on an imaginary dropoff location, build the dropoff or wait for halite until you can afford it.

In 4 player games, it was useful to multiply squares with enemies near them by 2 because you are likely to mine while inspired there. One of the best ways to lose a 4p game is to place the first dropoff where there are no enemies nearby to give inspired.

#### 3. pick_target
My ships have two modes. One for raw mining and one for quicker moves when nearby enemies.

The raw mining algorithm simulates what would happen if a ship visited every square (in a center-outwards manner) and mined on it until the square has less halite than a certain threshold or the ship becomes full. When searching outward for the best path the metric halitechange/ticks decides which path is best. If halitechange is negative the metric 0.001*halitechange-ticks is used, this gives the fastest path (or cheapeast if time is same). This means I use the same algorithm to find cheapest path as I do to maximize halite. When the square that gives the most halite per tick is chosen I track the path, modify the map with what it mined along the way and reserve where it is in the future so that next ship knows what squares are occupied.<p>
There are some options of what to do with the output of this algorithm. It gives what the ship would carry and where it would be at some timestep into the future and what the halite/tick is for all squares. One of the main uses I found was to check if the ship would be almost full when stepping onto an imaginary dropoff, if so then pick that target even though it might not be the one the gives the most halite/tick. I think my ships are almost always on the way to a new dropoff, but they mine on the way there. A problem with this approach is that we often dont arrive at the good places fast enough even though it is "more efficient" to mine while moving. For these circumstances I increase the threshold for what it must mine squares down to. (in fact this is how I make my ships move fast to drop when they are full, I tell them to only mine squares that have 10k halte on them)

This algorithm of mining to a threshold before moving seems to be optimal if the map always had uniform halite. But in practice, setting the threshold at 2/3 of the maps meanhalite. Simplified, it boils down to "mine on a square if it has more than 2/3 meanhalite, otherwise keep going to where you want to go"

The other mode, simpler, but more effective when plans change every tick is used nearby inspired squares, (which is 99% of 4p games). But its the same idea: <b>halite per tick</b>, but dont simulate anything. just calculate, if you mine 2 times on a square, and the square is 4 ticks away and you get 100 halite, then halite per tick is 100/(4+2). Whatever target you pick,use the shortest(cheapest) path there calculated by the other algorithm. 

#### 4. dir2dirs
this function creates alternatives to the first prefered direction. if the ship wants to go south, and its chosen target is south-east, the options could be for example 1.south 2.east 3.stay 4.west 5.north
#### 5. collisioncheck
if the first option is not allowed for some reason, then go through the other options in the order given by dir2dirs.
the full list of when to avoid enemies is given by avoidrules() in src/salboai/collisioncheck.jl
The variable names are pretty self explanatory. for example
if Ihavemoreshipsclose[p] && mydropointiscloser[p]
    avoid = false
end
#### 6. shipgeneration
The mining algorithm gives me for free the number of ticks it would take for a ship to become full, just stopping making ships when that time is greater than turns remaining works well in 2 player games. In 4 player games I never found a better way than a function of remaininghalite and number of ships I have.
  
