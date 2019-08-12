local tag = "XChat"

do util.AddNetworkString(tag) end

local print = epoe and epoe.RealPrint or print

net.Receive(tag,function(len,ply)
	local len  = net.ReadUInt(16)
	local data = net.ReadData(len)
	local msg  = util.Decompress(data)
	gamemode.Call("PlayerSay",ply,msg,false)
	print(ply:Nick()..": "..msg)
	net.Start(tag)
		net.WriteUInt(len,16)
		net.WriteData(data,len)
		net.WriteEntity(ply)
		net.WriteBool(not ply:Alive())
	net.Broadcast()
end)