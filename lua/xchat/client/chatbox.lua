local tag = "XChat"

if XChat and XChat.Reload then
	XChat:Reload() -- assume it's loaded already
end

surface.CreateFont(tag,{
	font = "Roboto",
	size = ScreenScale(6.7),
	weight = 500,
	antialias = true,
})

surface.CreateFont(tag.."-chat",{
	font = "Tahoma",
	size = ScreenScale(6.3),
	weight = 600, 
	antialias = true
})

XChat = XChat or {}
XChat.chatbox = XChat.chatbox or {}

local function sanityCheck()
	if not XChat.chatbox or next(XChat.chatbox) == nil then return false end
	local ok = true
	for _,pnl in next, XChat.chatbox do 
		if not IsValid(pnl) then ok = false end
	end
	return ok
end

function XChat:Recreate()
	self:Close()
	self:Init()
end

XChat.Reload = XChat.Recreate

function XChat:Init()
	local scrW,scrH = ScrW(),ScrH()
	local outerframe = vgui.Create("DFrame")
	outerframe:SetCookieName("XChat")
	local x, y = chat.GetChatBoxPos()
	local w, h = chat.GetChatBoxSize()

	local cx = outerframe:GetCookie("x", x)
	local cy = outerframe:GetCookie("y", y)
	local cw = outerframe:GetCookie("w", w)
	local ch = outerframe:GetCookie("h", h)
	outerframe:SetSize(cw, ch)
	outerframe:SetPos(cx, cy)
	outerframe:SetTitle("")
	outerframe:SetDraggable(true)
	outerframe:SetSizable(true)
	outerframe:MakePopup()
	outerframe.Paint = function(self,w,h)
		BlurBoxPanel(self,4,255,Color(0,0,0,200))
		--surface.SetDrawColor(20,20,20,200)
		--surface.DrawRect(0,0,w,h)
		--derma.SkinHook("Paint","Frame",self,w,h)

		surface.SetFont(tag)
		local x, y = surface.GetTextSize(GetHostName())
		surface.SetTextPos(w/2-x/2,28/2-y/2)
		surface.SetTextColor(255,255,255,255)
		surface.DrawText(GetHostName())
	end
	outerframe:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton",outerframe)
	closebutton:SetSize(32,18)
	closebutton:SetText("X")
	closebutton:SetFont(tag)
	closebutton.Paint = function(self,w,h)
		surface.SetDrawColor(0,0,0,215)
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(self:IsHovered() and 255 or 230,0,0,215)
		surface.DrawRect(1,1,w-2,h-2)
	end

	closebutton.OnMousePressed = function(self,btn)
		if btn == MOUSE_LEFT then XChat:Close() end
		if btn == MOUSE_RIGHT then
			self.menu = DermaMenu()
			self.menu:AddOption(("Close"),function() XChat:Close() end)
			self.menu:AddOption(("Recreate"),function() XChat:Recreate() end)
			self.menu:Open()
		end
	end

	outerframe.PerformLayout = function(self,w,h)
		closebutton:SetPos(w-32 - 2, 2)
	end


	local chatbox = vgui.Create("EditablePanel",outerframe)
	chatbox:Dock(FILL)
	chatbox:DockMargin(10,25,10,10)
	chatbox.Paint = function(self,w,h)
		surface.SetDrawColor(40,40,40,200)
		surface.DrawRect(0,0,w,h)
		surface.SetDrawColor(255,255,255,200)
		surface.DrawLine(0,h-20-1,w,h-20-1)
		surface.SetFont("Default")
		local x,y = surface.GetTextSize("Say:")
		surface.SetTextPos((x*0.3),h-(y)-scrW*0.002)
		surface.SetTextColor(190,190,190,255)
		surface.DrawText("Say:")
	end
	
	local chatlog = vgui.Create("RichText",chatbox)
	chatlog:Dock(FILL)
	chatlog:DockMargin(0,0,0,1)
	chatlog.PerformLayout = function(self)
		self:SetFontInternal(tag.."-chat")
	end

	local textentry = vgui.Create("DTextEntry",chatbox)
	textentry:Dock(BOTTOM)
	textentry:DockMargin(35,0,0,0)
	textentry:RequestFocus()
	textentry:SetHistoryEnabled(true)
	textentry:SetUpdateOnType(true)
	textentry.HistoryPos = 0
	textentry.OnKeyCodeTyped = function(self,code)
		if code == KEY_ENTER then
			if string.Trim(self:GetText()) == "" then return XChat:Close() end
			XChat:SendMessage(self:GetValue())
			self:AddHistory(self:GetText())
			self.HistoryPos = 0
			XChat:Close()
		end
		if code == KEY_UP then
			self.HistoryPos = self.HistoryPos-1
			self:UpdateFromHistory()
		elseif code == KEY_DOWN then
			self.HistoryPos = self.HistoryPos+1
			self:UpdateFromHistory()
		end
		if code == KEY_TAB then
			local text = gamemode.Call("OnChatTab",self:GetText())	
			self:SetText(text)
			gamemode.Call("ChatTextChanged",text)
			self:SetCaretPos(#self:GetText())
			timer.Simple(0,function() self:RequestFocus() end)
			return true
		end
		if code == KEY_ESCAPE then
			self.HistoryPos = 0
			XChat:Close()
			gui.HideGameUI()
		end

	end
	
	textentry.OnValueChange = function(self,text)
		gamemode.Call("ChatTextChanged",text)
	end

	XChat.chatbox = {}
	XChat.chatbox.outerframe  = outerframe
	XChat.chatbox.closebutton = closebutton
	XChat.chatbox.chatbox     = chatbox
	XChat.chatbox.chatlog     = chatlog
	XChat.chatbox.textentry   = textentry
	chatgui = outerframe

	self:Close()
end

function XChat:SendMessage(...)
	local data 	= util.Compress(...)
	local len 	= string.len(data or "")
	local ok 	= pcall(function()
		net.Start(tag)
			net.WriteUInt(len,16)
			net.WriteData(data,len)
		net.SendToServer()
	end)
	if not ok then LocalPlayer():ConCommand("say \"" .. ... .. "\"") end
end

function XChat:SaveCookies()
	local x,y,w,h = self.chatbox.outerframe:GetBounds()

	self.chatbox.outerframe:SetCookie("x", x)
	self.chatbox.outerframe:SetCookie("y", y)
	self.chatbox.outerframe:SetCookie("w", w)
	self.chatbox.outerframe:SetCookie("h", h)
end

function XChat:Open()
	if not sanityCheck() then XChat:Init() end
	XChat.chatbox.outerframe:Show()
	XChat.chatbox.textentry:RequestFocus()
	gamemode.Call("StartChat")
end

function XChat:Close()
	if not sanityCheck() then return end
	gui.EnableScreenClicker(false)
	XChat.chatbox.textentry:SetText("")
	XChat.chatbox.outerframe:Hide()
	gamemode.Call("ChatTextChanged","")
	gamemode.Call("FinishChat")

	self:SaveCookies()
end

XChat.chat_AddText = XChat.chat_AddText or chat.AddText
function chat.AddText(...)
	if not sanityCheck() then return XChat.chat_AddText(...) end
	XChat.chatbox.chatlog:AppendText("\n")
	local args = {...}
	for _,obj in next,args do
		local type = type(obj)
		if type == "table" then
			XChat.chatbox.chatlog:InsertColorChange(obj.r,obj.g,obj.b,255)
		elseif type == "string" then
			XChat.chatbox.chatlog:AppendText(obj)
		elseif obj:IsPlayer() then
			local col = GAMEMODE:GetTeamColor(obj)
			XChat.chatbox.chatlog:InsertColorChange(col.r,col.g,col.b,255)
			XChat.chatbox.chatlog:AppendText(obj:Nick())
		end
	end

	chat.PlaySound()
	XChat.chat_AddText(...)
end

hook.Add("PlayerBindPress",tag,function(ply,bind,pressed)
	if pressed and bind == "messagemode" then
		XChat:Open()
		return true
	end
end)

--[[hook.Add("HUDShouldDraw", tag, function(name) -- Remove comments if you want to work on a chathud. 
	if name == "CHudChat" then
		return false
	end
end)]]

hook.Add("PreRender",tag,function()
	if (XChat.chatbox and IsValid(XChat.chatbox.outerframe) and XChat.chatbox.outerframe:IsVisible()) and gui.IsGameUIVisible() then
		if IsValid(XChat.chatbox.closebutton) and IsValid(XChat.chatbox.closebutton.menu) then
			XChat.chatbox.closebutton.menu:Remove()
		end
		XChat:Close()
		gui.HideGameUI()
		return true
	end
end)

hook.Add("ChatText", tag, function(_,_,text,type)
	if type == "none" or type == "servermsg" then
		if not IsValid(XChat.chatbox.chatlog) then
			Msg("[XChat] ")
			print("Attempting to send message before chatlog creation! ("..text..")")
			return
		end
		XChat.chatbox.chatlog:AppendText("\n")
		XChat.chatbox.chatlog:InsertColorChange(255,255,255,255)
		XChat.chatbox.chatlog:AppendText(text)
	end
end)

hook.Add("Initialize",tag,function()
	if XChat and XChat.Init then
		XChat:Init()
		hook.Remove("Initialize",tag)
	end
end)
