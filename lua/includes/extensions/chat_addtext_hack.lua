if chat_addtext_hack then return end
chat_addtext_hack = true

if SERVER then
	AddCSLuaFile("chat_addtext_hack.lua")
	return
end

local origchat_AddText = chat.AddText

chat.AddText = function(...)
	if PrimaryChatAddText then
		if PrimaryChatAddText(...) then
			origchat_AddText(...)
		end
	else
		origchat_AddText(...)
	end
end