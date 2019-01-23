using Halite3

function letsplay()
	Halite3.warmup(1)
	g = Halite3.init()
	s = Halite3.startstate(g)

	botname = "andersgee"
	maxturn = 401 + div((size(g.halite, 1)-32)*100, 32)

	notcompiled = [true]
	while true
		if notcompiled[1]
			Halite3.ready(botname)
			notcompiled[1] = false
		end

		turn = Halite3.update_frame!(g)
		cmds = Halite3.tick(s, g, turn, maxturn)
		Halite3.sendcommands(cmds)
	end
end

letsplay()