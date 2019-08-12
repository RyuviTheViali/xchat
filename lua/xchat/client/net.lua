local tag = "XChat"

net.Receive(tag,function()
	local len   = net.ReadUInt(16)
	local data  = net.ReadData(len)
	local ply   = net.ReadEntity()
	local alive = net.ReadBool()
	local msg 	= util.Decompress(data)
	gamemode.Call("OnPlayerChat",ply,msg,false,alive)
end)