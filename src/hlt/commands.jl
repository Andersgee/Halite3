ready(botname) = println(botname)
generate_ship() = "g"

function move(shipid, dir)
	dir == 1 && return "m $(shipid) s"
	dir == 2 && return "m $(shipid) e"
	dir == 3 && return "m $(shipid) n"
	dir == 4 && return "m $(shipid) w"
	dir == 5 && return "m $(shipid) o" #stay still and mine
	dir == 6 && return "c $(shipid)" #convert to dropoff
end