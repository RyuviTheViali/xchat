local function MakeGlobalKey(filename)
	_G["XCHAT"] = _G["XCHAT"] or {}
	_G["XCHAT"][filename:Left(-5):upper()] = true
end

local function LoadFiles(dir)
	for k,v in pairs((file.Find(dir.."/*.lua","LUA"))) do
		local p = dir.."/"..v
		MakeGlobalKey(v)
		include(p)
		if SERVER then AddCSLuaFile(p) end
	end
	for k,v in pairs((file.Find(dir.."/client/*.lua","LUA"))) do
		local p = dir.."/client/"..v
		if CLIENT then
			MakeGlobalKey(v)
			include(p)
		end
		if SERVER then AddCSLuaFile(p) end
	end
	if SERVER then
		for k,v in pairs((file.Find(dir.."/server/*.lua","LUA"))) do
			MakeGlobalKey(v)
			include(dir.."/server/"..v)
		end
	end
end
LoadFiles("xchat")