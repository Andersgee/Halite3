function commandstring(IDmyships::Array{Int64,1}, pickeddir::Array{Int64,1}, willgenerateship::Bool)
	cmds = String[]
	push!.((cmds,), Halite3.move.(IDmyships, pickeddir))
	if willgenerateship; push!(cmds, generate_ship()); end
	return cmds
end

function tick(s::State, g::GameMap, turn::Int64, maxturn::Int64)

	halitemap, various, positions, vectors, matrices = datacollections(g, turn, maxturn)

	shouldgenerateship = turn < div(maxturn,3) || (various.turns_remaining > 90 && sum(halitemap.M)/various.Nmyships > 1800)

	filters = Mfilters(s, halitemap, matrices, positions, vectors, various, shouldgenerateship)
	vectors.gameisending = filters.mhdmydropoints[positions.myships] .> (various.turns_remaining-3)

	#dropoff placement
	if various.NPlayers==2
		positions.desirednewdropoffs = newdropoffs_2p(s, various, halitemap, matrices, positions, filters)
	elseif various.NPlayers>2 && halitemap.sz[1]<=40
		positions.desirednewdropoffs = newdropoffs_4p_bordersonly_ish(s, various, halitemap, matrices, positions, filters)
	else
		positions.desirednewdropoffs = newdropoffs_4p(s, various, halitemap, matrices, positions, filters)
	end
	Mdesirednewdropoffsnearby = get_Mdesirednewdropoffsnearby(s, halitemap.sz, positions.desirednewdropoffs, positions)
	
	update_state!(s, various, vectors, positions, halitemap)

	#pathfinding, targetselection and prefered direction to move
	dir, target, p_closestdrop, Vwantstomine, shiponthewaytonewdropoff, hastomovefromdropN, fullshipsonthewaytonewdropoff, newshiphastimetobecomefull = pick_target(s, halitemap, vectors, matrices, filters, positions, various, shouldgenerateship)

	#convert to 5 alternative dirs depending on prefered dir and where target is
	dirs = dir2dirs(dir, target, p_closestdrop, Vwantstomine, positions, vectors, halitemap, Mdesirednewdropoffsnearby)

	#deal with creating a dropoff if a ship happen to be standing on a desired location
	available_halite, waiting_for_halite, n_willbuild = buildnewdropoff!(shiponthewaytonewdropoff, s, positions, various, vectors, halitemap, fullshipsonthewaytonewdropoff, Mdesirednewdropoffsnearby)

	#use alternative dirs if prefered dir is bad
	pickeddir, unoccupiedshipyard = collisioncheck(dirs, s, matrices, filters, various, positions, vectors, halitemap, Vwantstomine, hastomovefromdropN, n_willbuild, Mdesirednewdropoffsnearby)

	#make decision if new ship should be generated
	if various.NPlayers==2 && halitemap.sz[1]<=48 #|| various.NPlayers>2 && halitemap.sz[1]<=40
		if various.NPlayers==2
			margin=30
		else
			margin=20
		end
		if (various.Nmyships-margin)>various.MAX_Nenemyships
			willgenerateship=false
		else
			willgenerateship = available_halite >= 1000 && unoccupiedshipyard && !waiting_for_halite && (newshiphastimetobecomefull || turn < div(maxturn,3))
		end
	elseif various.NPlayers==2 
		willgenerateship = available_halite >= 1000 && unoccupiedshipyard && !waiting_for_halite && shouldgenerateship && newshiphastimetobecomefull
	else
		willgenerateship = available_halite >= 1000 && unoccupiedshipyard && !waiting_for_halite && shouldgenerateship
	end

	return commandstring(various.IDmyships, pickeddir, willgenerateship)
end
