
function targetlog(io,turn,yx, Vdebugstring, color)
    #format for f-logs for use in flourine replay viewer
    flog = string("{\"t\":", turn-1, ",\"x\":", yx[2]-1, ",\"y\":", yx[1]-1, ",\"msg\":\"",join(Vdebugstring, "<br>"),"\",\"color\":\"#",color,"\"},")
    println(io, flog)
    flush(io)
end

function shiplog(io,turn,yx, Vdebugstring)
    #format for f-logs for use in flourine replay viewer
    flog = string("{\"t\":", turn-1, ",\"x\":", yx[2]-1, ",\"y\":", yx[1]-1, ",\"msg\":\"",join(Vdebugstring, "<br>"),"\"},")
    println(io, flog)
    flush(io)
end
