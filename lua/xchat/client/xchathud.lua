local function XChatHUDInit()

XChatHUD = XChatHUD or {}

XChatHUD.ChatHUD = {
	Config = {
		MaxWidth       = 500,
		MaxHeight      = 1200,
		HeightSpacing  = 3,
		HistoryPersist = 20,
		Modifiers = {
			["...."]    = {type="font",val="DefaultFixed"},
			["!!!!"]    = {type="font",val="Trebuchet24" },
			["!!!!!11"] = {type="font",val="DermaLarge"  }
		},
		Shortcuts = {		
			ovo = "<texture=masks/ovo>",
		}
	},
	Fonts = {
		Default = {
			Name = "chathud_default",
			Data = {
				font       = "Tahoma",
				size       = 18,
				weight     = 600,
				antialias  = true,
				shadow     = true,
				outline    = false,
				prettyblur = 1
			} 
		},
		ChatPrint = {
			Name  = "chathud_chatprint",
			Color = Color(168,127,255,255),
			Data  = {
				font       = "Tahoma",
				size       = 24,
				weight     = 600,
				antialias  = true,
				shadow     = true,
				outline    = false,
				prettyblur = 1
			}
		}
	},
	Tags = {}
}

for k,v in pairs(file.Find("materials/icon16/*.png","GAME")) do
	XChatHUD.ChatHUD.Config.Shortcuts[v:gsub("(%.png)$","")] = "<texture=materials/icon16/"..v..",16>"
end

for k,v in pairs(XChatHUD.ChatHUD.Fonts) do
	surface.CreateFont(v.Name,v.Data)
end

XChatHUD.Visible          = CreateClientConVar("xchathud_show"       ,"1"   ,true,false)
XChatHUD.TimeStamps       = CreateClientConVar("xchathud_timestamps" ,"1"   ,true,false)
XChatHUD.HeightMultiplier = CreateClientConVar("xchathud_height_mult","0.76",true,false)
XChatHUD.WidthMultiplier  = CreateClientConVar("xchathud_width_mult" ,"0.3" ,true,false)

XChatHUD.XMarkup = XMarkup()
XChatHUD.XMarkup:SetEditable(false)
XChatHUD.LifeTime = 20

local lastdraw = 0

function XChatHUD.AddText(...)
	if lastdraw < RealTime() then return end
	
	if XChatHUD.Visible:GetBool() then
		XChatHUD.Cleared = false
	else
		if not XChatHUD.Cleared then
			XChatHUD.XMarkup:Clear()
			XChatHUD.Cleared = true
		end
		return
	end
	
	local args = {}
	
	for k,v in pairs({...}) do
		local t = type(v)
		
		if t == "Player" then
			table.insert(args,team.GetColor(v:Team()))
			table.insert(args,v:Nick())
			table.insert(args,Color(255,255,255,255))
		elseif t == "string" then
			if v == ": sh" or v:find("%ssh%s") then
				XChatHUD.XMarkup:TagPanic()
			end
		
			v = v:gsub("<remember=(.-)>(.-)</remember>",function(key,val) 
				XChatHUD.ChatHUD.Config.Shortcuts[key] = val
			end)
		
			v = v:gsub("(:[%a%d]-:)",function(str)
				str = str:sub(2,-2)
				if XChatHUD.ChatHUD.Config.Shortcuts[str] then
					return XChatHUD.ChatHUD.Config.Shortcuts[str]
				end
			end)
			
			v = v:gsub("\\n","\n")
			v = v:gsub("\\t","\t")
			
			for pattern,font in pairs(XChatHUD.ChatHUD.Config.Modifiers) do
				if v:find(pattern,nil,true) then
					table.insert(args,#args-1,font)
				end
			end
			
			table.insert(args,v)
		else
			table.insert(args,v)
		end
	end
	
	local m = XChatHUD.XMarkup
	
	m:BeginLifeTime(XChatHUD.LifeTime)
		m:AddFont("chathud_default")
		m:AddTable(args,true)
		m:AddTagStopper()
		m:AddString("\n")
	m:EndLifeTime()
	m:SetMaxWidth(ScrW()*XChatHUD.WidthMultiplier:GetFloat())
		
	for k,v in pairs(XChatHUD.ChatHUD.Tags) do
		m.tags[k] = v
	end
end

local pacoff = 30
function XChatHUD.Draw()
	if not XChatHUD.Visible:GetBool() then return end
	
	local m = XChatHUD.XMarkup
	
	local w,h = ScrW(),ScrH()
	local x,y = 30,h*XChatHUD.HeightMultiplier:GetFloat()
	
	if pace and pace.IsActive() and pace.Editor:IsActive() then
		pacoff = pace.Editor:GetWide()+30
		x = pacoff
	else
		x = 30
	end
	
	y = y-m.height
	
	m:Draw(x,y,w,h)
	
	lastdraw = RealTime()+3
end

function XChatHUD.MouseInput(button,down,x,y)
	if not XChatHUD.Visible:GetBool() then return end
	
	XChatHUD.XMarkup:OnMouseInput(button,down,x,y)
end

function XChatHUD.CanRunAnnoyingTags()
	local you = LocalPlayer()
	local him = XChatHUD.GetPlayer()
	
	return not him:IsValid() and him.IsFriend and you ~= chathud.GetPlayer() and not you:IsFriend(him)
end

function XChatHUD.GetPlayer()
	return XChatHUD.CurrentPlayer or NULL
end


hook.Add("PlayerSay","XChatHUD",function(ply)
	XChatHUD.CurrentPlayer = ply
	
	timer.Simple(0,function()
		XChatHUD.CurrentPlayer = NULL
	end)
end)

hook.Add("OnPlayerChat","XChatHUD",function(ply)
	XChatHUD.CurrentPlayer = ply
	
	timer.Simple(0,function()
		XChatHUD.CurrentPlayer = NULL
	end)
end)
--[[
hook.Remove("ChatText","XChatHUD",function(_,_,msg)
	local datetxt = "["..os.date("%I:%M:%S %p",os.time()).."] "
	local showdate = XChatHUD.TimeStamps:GetBool()
	
	print("aaa?",tostring(showdate and datetxt..msg or msg))
	
	XChatHUD.AddText({
		type = "font",
		val  = XChatHUD.ChatHUD.Fonts.ChatPrint.Name
	},XChatHUD.ChatHUD.Fonts.ChatPrint.Color,tostring(showdate and datetxt..msg or msg))
end)
]]
hook.Add("HUDShouldDraw","XChatHUD",function(name)
	if name == "CHudChat" and XChatHUD.Visible:GetBool() then
		return false
	end
end)

hook.Add("HUDPaint","chathud",function()
	if XChatHUD.Visible:GetBool() then
		_G.PrimaryChatAddText = XChatHUD.AddText
	else
		_G.PrimaryChatAddText = nil
	end
	
	XChatHUD.Draw()
end)

XChatHUD.Recreate = function()
	XChatHUDInit()
end

end
hook.Add("InitPostEntity","XChatHUDInit",XChatHUDInit)

if LocalPlayer and LocalPlayer():IsValid() then
	XChatHUDInit()
end