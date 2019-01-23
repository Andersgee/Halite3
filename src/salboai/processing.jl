
include("diamondfilter.jl")

leavecost(M::Array{Int64,2}) = div.(M, 10) #leaving rounds down
#leavecost(m::Int64) = div(m,10)

ema(y, s, a) = a*y+(1-a)*s #exponential moving average



function Mfilters(s::State, halitemap::Halitemap, matrices::Matrices, positions::Positions, vectors::Vectors, various::Various, shouldgenerateship::Bool)
	Y,X=size(matrices.enemyships)
	Minspired = df.diamondfilter(matrices.enemyships, 4).>=2
	Minspired_future1 = df.diamondfilter(matrices.enemyships, 3).>=2
	Minspired_future1plusone = df.diamondfilter(matrices.enemyships, 3).>=3

	meanhalite=sum(halitemap.M)/prod(size(halitemap.M))
	if !shouldgenerateship
		abnormaly_big_halitesquares = (halitemap.M.>s.M_tick1) .| (halitemap.M.>(5*max(1,meanhalite)))
	else
		abnormaly_big_halitesquares = halitemap.M.>s.M_tick1
	end
	Mhasbighalitesquarecloseby = df.diamondfilter(abnormaly_big_halitesquares.*1, 8).>0
	#Minspired_future2 = df.diamondfilter(matrices.enemyships, 2).>=2

	Mgoodinspired = df.diamondfilter(Minspired .* 1, 1).>=2

	Mgoodmultiplier = Minspired .+ Mgoodinspired .+ 1

    #if various.NPlayers>2 && halitemap.sz[1]<=48 && length(positions.mydroppoints)>1
    #    Minspiredcloseby = df.diamondfilter(Minspired .* 1, 6).>0
	if various.NPlayers>2
		Minspiredcloseby = df.diamondfilter(Minspired .* 1, 5).>0
	else
		Minspiredcloseby = df.diamondfilter(Minspired .* 1, 3).>0
	end
	
	enemiesCANTmove = positions.enemyships[halitemap.leavecost[positions.enemyships].>vectors.enemyshipshalite]
	enemiescanmove = positions.enemyships[halitemap.leavecost[positions.enemyships].<=vectors.enemyshipshalite]
	Menemyshipsnearby_modified = zeros(Int64, halitemap.sz)
	Menemyshipsnearby_modified[enemiescanmove] .= 1
	Menemyshipsnearby_modified = df.diamondfilter(Menemyshipsnearby_modified, 1)
	Menemyshipsnearby_modified[enemiesCANTmove] .= 1
	Menemyshipsnearby = Menemyshipsnearby_modified .> 0


	Mmydroppointsnearby = df.diamondfilter(matrices.mydroppoints, 1).>=1
	Mmydroppointsnearbyr2 = df.diamondfilter(matrices.mydroppoints, 2).>=1

	Menemyshipshalitesumnearby = df.diamondfilter(matrices.enemyshipshalite, 1)

    #=
	Nenemyships = length(positions.enemyships)
	if Nenemyships>0
		MenemyshipshaliteSINGLEnearby = zeros(Int64, Y,X,Nenemyships)
		for n=1:Nenemyships
			MenemyshipshaliteSINGLEnearby[positions.enemyships[n],n] = vectors.enemyshipshalite[n]+1
			#MenemyshipshaliteSINGLEnearby[:,:,n] .= df.diamondfilter(view(MenemyshipshaliteSINGLEnearby, :,:,n), 1)
            MenemyshipshaliteSINGLEnearby[:,:,n] .= df.diamondfilter(MenemyshipshaliteSINGLEnearby[:,:,n], 1)
		end

		#MenemyshipshaliteMINnearby=minimum(MenemyshipshaliteSINGLEnearby, dims=3)[:,:]
		MenemyshipshaliteMAXnearby=maximum(MenemyshipshaliteSINGLEnearby, dims=3)[:,:]

		MenemyshipshaliteMINnearby=zeros(Int64, Y,X)
		for x=1:X, y=1:Y, i=1:Nenemyships
			if MenemyshipshaliteSINGLEnearby[y,x,i]>0
				if MenemyshipshaliteMINnearby[y,x]>0
					MenemyshipshaliteMINnearby[y,x] = min(MenemyshipshaliteMINnearby[y,x], MenemyshipshaliteSINGLEnearby[y,x,i])
				else
					MenemyshipshaliteMINnearby[y,x] = MenemyshipshaliteSINGLEnearby[y,x,i]
				end
			end
		end
		MenemyshipshaliteMINnearby = max.(0, MenemyshipshaliteMINnearby.-1)

	else
		MenemyshipshaliteMINnearby=zeros(Int64, Y,X)
		MenemyshipshaliteMAXnearby=zeros(Int64, Y,X)
	end
    =#
    Nenemyships = length(positions.enemyships)
    if Nenemyships>0
        diamondpos=(CartesianIndex(0,0), CartesianIndex(1,0),CartesianIndex(0,1),CartesianIndex(-1,0),CartesianIndex(0,-1))
        #wrap(sz::Tuple{Int64,Int64}, p::CartesianIndex{2}) = CartesianIndex(mod1(p[1],sz[1]), mod1(p[2],sz[2]))

        MenemyshipshaliteMINnearby=fill(typemax(Int64),Y,X)
        MenemyshipshaliteMAXnearby=zeros(Int64,Y,X)
         
        for (q,h) in zip(positions.enemyships, vectors.enemyshipshalite)
            for k in diamondpos
                p=wrap(halitemap.sz, q+k)
                MenemyshipshaliteMINnearby[p]=min(h+1,MenemyshipshaliteMINnearby[p])
                MenemyshipshaliteMAXnearby[p]=max(h,MenemyshipshaliteMAXnearby[p])
            end
        end
        MenemyshipshaliteMINnearby[MenemyshipshaliteMINnearby.==typemax(Int64)] .= 1
        MenemyshipshaliteMINnearby.-=1
    else
        MenemyshipshaliteMINnearby=zeros(Int64, Y,X)
        MenemyshipshaliteMAXnearby=zeros(Int64, Y,X)
    end

    Mmyshipsclose_unmodified = df.diamondfilter(matrices.myships, 3)
    MIhavemoreshipsclose_unmodified =  Mmyshipsclose_unmodified .> df.diamondfilter(matrices.enemyships, 3)

	matrices_myships_modified = copy(matrices.myships)
	mostnotbecounted = positions.myships[vectors.myshipshalite.>750]
    matrices_myships_modified[mostnotbecounted] .= 0
	
	matrices_enemyships_modified = copy(matrices.enemyships)
	mostnotbecounted_enemy = positions.enemyships[vectors.enemyshipshalite.>900]
	matrices_enemyships_modified[mostnotbecounted_enemy] .= 0

	Mmyshipsclose = df.diamondfilter(matrices_myships_modified, 3)
	Menemyshipsclose = df.diamondfilter(matrices_enemyships_modified, 3)

	
	MIhavemoreshipsclose = Mmyshipsclose .> Menemyshipsclose
	MEnemyhavemoreshipsclose = Menemyshipsclose .> Mmyshipsclose

	

	if various.NPlayers>2
		if length(positions.mydroppoints)==1
			margin=1
		else
			margin=1
		end
		matrices_enemyships1_modified=copy(matrices.enemyships1)
		matrices_enemyships2_modified=copy(matrices.enemyships2)
		matrices_enemyships3_modified=copy(matrices.enemyships3)

		matrices_enemyships1_modified[mostnotbecounted_enemy] .= 0
		matrices_enemyships2_modified[mostnotbecounted_enemy] .= 0
		matrices_enemyships3_modified[mostnotbecounted_enemy] .= 0

		Menemyshipsclose1 = df.diamondfilter(matrices_enemyships1_modified, 3)
		Menemyshipsclose2 = df.diamondfilter(matrices_enemyships2_modified, 3)
		Menemyshipsclose3 = df.diamondfilter(matrices_enemyships3_modified, 3)

		maxnotsum = max.(Menemyshipsclose1,Menemyshipsclose2,Menemyshipsclose3)
		MIhavemoreshipsclose = Mmyshipsclose .> (maxnotsum .+ margin)

		MEnemyhavemoreshipsclose = maxnotsum .> Mmyshipsclose


		Menemyshipsclose1_unmodified = df.diamondfilter(matrices.enemyships1, 3)
		Menemyshipsclose2_unmodified = df.diamondfilter(matrices.enemyships2, 3)
		Menemyshipsclose3_unmodified = df.diamondfilter(matrices.enemyships3, 3)
		maxnotsum_unmodified = max.(Menemyshipsclose1,Menemyshipsclose2,Menemyshipsclose3)
		MIhavemoreshipsclose_unmodified = Mmyshipsclose_unmodified .> maxnotsum_unmodified
	end


    hasnewlycreateddrop=s.ticks_since_created_dropoff<20
    if various.NPlayers>2 && halitemap.sz[1]>=48
        hasnewlycreateddrop=s.ticks_since_created_dropoff<25
    end

	Mnewestdropbonusmultiplier=ones(Int64, halitemap.sz)
	if hasnewlycreateddrop && length(positions.mydroppoints) >= 2
		Mnewestdropbonusmultiplier = zeros(Int64, halitemap.sz)
		Mnewestdropbonusmultiplier[s.p_newestdrop] = 1
		Mnewestdropbonusmultiplier = df.diamondfilter(Mnewestdropbonusmultiplier, 6)
		Mnewestdropbonusmultiplier = Mnewestdropbonusmultiplier .+ 1
	end
		


	Mmyshipyardiscloser, Mmydropointiscloser, mhdmydropoints, Mmhdplayerborder = calc_Mdroppointsmhd(halitemap, various, positions, vectors, matrices)

	#Mmultiplier = Minspired.*2 .+ 1
    Mmultiplier = Minspired .+ 1


	filters = Filters(Minspired, Minspired_future1, Minspiredcloseby, Menemyshipsnearby, Mmydroppointsnearby, Mmydroppointsnearbyr2, MenemyshipshaliteMINnearby, MenemyshipshaliteMAXnearby, MIhavemoreshipsclose, MEnemyhavemoreshipsclose, Mmyshipyardiscloser, Mmydropointiscloser, mhdmydropoints, Mmultiplier, Mmyshipsclose, Mgoodmultiplier, Mnewestdropbonusmultiplier, Mmhdplayerborder, Menemyshipsclose, Mhasbighalitesquarecloseby, Minspired_future1plusone, MIhavemoreshipsclose_unmodified)
	return filters
end

mutable struct Filters
	inspired::BitArray{2}
	inspired_future1::BitArray{2}
	inspiredcloseby::BitArray{2}

	enemyshipisnearby::BitArray{2}
	mydroppointisnearby::BitArray{2}
	mydroppointisnearbyr2::BitArray{2}

	enemyshipshaliteMINnearby::Array{Int64,2}
	enemyshipshaliteMAXnearby::Array{Int64,2}

	Ihavemoreshipsclose::BitArray{2}
	Enemyhavemoreshipsclose::BitArray{2}

	myshipyardiscloser::BitArray{2}
	mydropointiscloser::BitArray{2}
	mhdmydropoints::Array{Int64,2}

	multiplier::Array{Int64,2}
	myshipsclose::Array{Int64,2}

	goodmultiplier::Array{Int64,2}
	newestdropbonusmultiplier::Array{Int64,2}
	mhdplayerborder::BitArray{2}
	enemyshipsclose::Array{Int64,2}
	hasbighalitesquarecloseby::BitArray{2}

	inspired_future1plusone::BitArray{2}
	Ihavemoreshipsclose_unmodified::BitArray{2}
end

function decision_generate_ship(turn, maxturn)
	#probably something more sophisticated here..
	shouldgenerateship = turn<maxturn/2
	return shouldgenerateship
end


function mhdo(sz)
    #manhattan distance matrix with origin (zero) in the middle (use it in later by shifting to desired origin)
    o = div.(sz,2)
    #o=CartesianIndex(ceil.(Int,Tuple(sz)./2))
    return [abs(o[1]-y)+abs(o[2]-x) for y=1:sz[1], x=1:sz[2]]
end

function mhdP(sz,P, mhdc)
    #returns manhattand distance to all squares measured from the CLOSEST point in P to that square
    o = div.(sz,2)
    A=cat([circshift(mhdc,(p[1]-o[1],p[2]-o[2])) for p in P]..., dims=3)
    return minimum(A, dims=3)[:,:]
end


function calc_Mdroppointsmhd(halitemap, various, positions, vectors, matrices)
	
	sz = halitemap.sz
	mhdc=mhdo(sz)
	mhdmydropoints = mhdP(sz, positions.mydroppoints, mhdc)
	mhdmyshipyard = mhdP(sz, [positions.myshipyard], mhdc)

	if length(positions.enemydroppoints)>0
		mhdenemydropoints = mhdP(sz, positions.enemydroppoints, mhdc)
		mhdenemyshipyards = mhdP(sz, positions.enemyshipyards, mhdc)
	else
		mhdenemydropoints = ones(Int64,sz)*999 #single player
		mhdenemyshipyards = ones(Int64,sz)*999 #single player
	end

	Mmydropointiscloser = mhdmydropoints .<= mhdenemydropoints
	Mmyshipyardiscloser = mhdmyshipyard .<= mhdenemyshipyards

    if various.NPlayers==2
        Mmhdplayerborder = (mhdmyshipyard .== mhdenemyshipyards) .| ((mhdmyshipyard.-1) .== mhdenemyshipyards)
    else
        Mmhdplayerborder = (mhdmyshipyard .== mhdenemyshipyards) .| ((mhdmyshipyard.-1) .== mhdenemyshipyards) .| ((mhdmyshipyard.-2) .== mhdenemyshipyards)
    end

	return Mmyshipyardiscloser, Mmydropointiscloser, mhdmydropoints, Mmhdplayerborder
end

function gameending(Pmyships, Mmhdmydropoints, turns_remaining)
	Vgameisending = Mmhdmydropoints[Pmyships] .> (turns_remaining-3)
	return Vgameisending
end
