setfenv(1,_G)

local META = {}
META.__index = META

function XMarkup()
	local self = {
		w              = 0,
		h              = 0,
		chunks         = {},
		current_x      = 0,
		current_y      = 0,
		current_width  = 0,
		current_height = 0
	}
	
	setmetatable(self,META)
	
	self:Invalidate()

	return self
end

local function get_set(tbl,name,def)
    tbl["Set"..name] = function(self,var)
    	self[name] = var
	end
	
    tbl["Get"..name] = function(self,var)
    	return self[name]
    end
    
    tbl[name] = def
end

local function parse_hexcolor(col)
	if not col then
		col = "ff00ff"
	end

	col = col:upper()
	local l = col:len()
	
	local rgb
	
	if l == 6 or l == 8 then
		rgb = {}
		
		for pair in string.gmatch(col,"%x%x") do
			local i = tonumber(pair,16)
			if i then
				table.insert(rgb,i)
			end
		end

		while #rgb < 4 do
			table.insert(rgb,255)
		end
	elseif l == 3 then
		rgb = {}
		
		for pair in string.gmatch(col,"%x") do
			local i = tonumber(pair..pair,16)
			if i then
				table.insert(rgb,i)
			end
		end

		while #rgb < 4 do
			table.insert(rgb,255)
		end
	end

	return rgb and Color(unpack(rgb))
end

get_set(META,"Table"      , {}   )
get_set(META,"MaxWidth"   , 500  )
get_set(META,"ControlDown", false)
get_set(META,"LineWrap"   , true )
get_set(META,"ShiftDown"  , false)
get_set(META,"Editable"   , true )
get_set(META,"Multiline"  , true )

function META:SetMaxWidth(w)
	if self.lastmw ~= w then
		self.MaxWidth    = w
		self.need_layout = true
		self.lastmw      = w
	end
end

function META:SetLineWrap(b)
	self.LineWrap    = b
	self.need_layout = true
end

local R,G,B,A = 1,1,1,1
local X,Y     = 0,0

local EXT
local CURRENT_MATRIX
local gmod   = gmod
local mstack = {}

if gmod then
	local TEMP_CLR = Color (R,G,B,A)
	local TEMP_VEC = Vector(0,0,0)
	local TEMP_ANG = Angle (0,0,0)

	local white = Material("vgui/white")

	do
		local stack = {}
		local i = 0
		
		function mstack.Push(identity)
			stack[i] = mstack.matrix or Matrix()
			mstack.matrix = identity and Matrix() or (Matrix()*stack[i])
			
			i = i+1
			
			return mstack.matrix
		end

		function mstack.Pop()
			i = i-1
			
			mstack.matrix = stack[i]
		end
	end

	function mstack.Translate(x,y,z)
		TEMP_VEC.x = x or 0
		TEMP_VEC.y = y or 0

		mstack.matrix:Translate(TEMP_VEC)
	end

	function mstack.Rotate(a,x,y,z)
		TEMP_ANG.y = a or 0

		mstack.matrix:Rotate(TEMP_ANG)
	end

	function mstack.Scale(x,y,z)
		TEMP_VEC.x = x or 0
		TEMP_VEC.y = y or 0

		mstack.matrix:Scale(TEMP_VEC)
	end

	EXT = {
		SetClipboard = function(txt)
			txt = tostring(txt or "")
			local _,count = txt:gsub("\n","\n")
			txt = txt..("_"):rep(count)

			local b = vgui.Create("DTextEntry",nil,"ClipboardCopyHelper")
				b:SetVisible(false)
				b:SetText(txt)
				b:SelectAllText()
				b:CutSelected()
				b:Remove()
		end,
		GetClipboard = function()
			return "gmod has no way to get clipboard data!"
		end,
		TypeOf = function(v)
			if type(v) == "table" and
				type(v.r) == "number" and
				type(v.g) == "number" and
				type(v.b) == "number"
			then
				return "color"
			end
			
			return type(v)
		end,
		Rand = math.Rand,
		LogF = function(fmt,...)
			MsgN(string.format(fmt,...))
		end,
		GetFrameTime = FrameTime,
		GetTime = RealTime,
		Color = Color,
		CreateConVar = function(name,def)
			return CreateClientConVar(name,tostring(def),true,false)
		end,
		GetConVarFloat = function(c)
			return c:GetFloat()
		end,
		HSVToColor = function(h,s,v)
			local c = HSVToColor(h%360,s,v)
			return c.r,c.g,c.b
		end,
		SetMaterial = function(mat)
			surface.SetMaterial(mat or white)
		end,
		SetWhiteTexture = function(mat)
			surface.SetMaterial(white)
		end,
		DrawLine = surface.DrawLine,
		SetColor = function(r,g,b,a)
			local oldr,oldg,oldb,olda = R,G,B,A
			
			R = r or 1
			G = g or 1
			B = b or 1
			A = a or 1

			if R <= 1 then R = R*255 end
			if G <= 1 then G = G*255 end
			if B <= 1 then B = B*255 end
			if A <= 1 then A = A*255 end

			surface.SetTextColor(R,G,B,A)
			surface.SetDrawColor(R,G,B,A)
			
			return oldr,oldg,oldb,olda
		end,
		GetColor = function()
			return R,G,B,A
		end,
		DrawRect = surface.DrawTexturedRect,
		CreateFont = surface.CreateFont,
		GetTextSize = function(str)
			str = str:gsub("\t","    ")
			str = str:gsub("&","¤")

			local w,h = surface.GetTextSize(str)
			return w,h
		end,
		SetTextPos = surface.SetTextPos,
		DrawText = surface.DrawText,
		SetFont = function(font)
			if not pcall(surface.SetFont,font) then
				surface.SetFont("DermaDefault")
			end
		end,
		GetScreenHeight = ScrH,
		GetScreenWidth = ScrW,
		GetMousePos = function()
			return gui.MousePos()
		end,
		SetCullClockWise = function(b)
			render.CullMode(b and MATERIAL_CULLMODE_CW or MATERIAL_CULLMODE_CCW)
		end,
		FindMaterial = function(path)
			if _G.pac and path:find("http") then
				local mat = CreateMaterial("chathud_texture_tag"..util.CRC(path).."_"..FrameNumber(),"UnlitGeneric",{})
				
				pac.urltex.GetMaterialFromURL(path,function(_mat)
					mat:SetTexture("$basetexture", _mat:GetTexture("$basetexture"))
				end,nil,"UnlitGeneric",size,false)
				
				mat:SetFloat("$alpha",0.999)
				
				return mat
			else
				local mat = Material(path)
				local shader = mat:GetShader()
				
				if shader == "VertexLitGeneric" or shader == "Cable" then
					local tex_path = mat:GetString("$basetexture")

					if tex_path then
						local params = {}

						params["$basetexture"] = tex_path
						params["$vertexcolor"] = 1
						params["$vertexalpha"] = 1

						mat = CreateMaterial("markup_fixmat_"..tex_path,"UnlitGeneric",params)
					end
				end

				return mat
			end
		end,

		TranslateMatrix = mstack.Translate,
		ScaleMatrix = mstack.Scale,
		RotateMatrix = mstack.Rotate,
		CreateMatrix = mstack.Push,
		PopMatrix = function()
			mstack.Pop()
			cam.PopModelMatrix()
		end,
		PushMatrix = function()
			cam.PushModelMatrix(mstack.matrix)
		end,
		OpenURL = function(str)
			gui.OpenURL(str)
		end,
		SetAlphaMultiplier = surface.SetAlphaMultiplier,
	}
else
	EXT = {
		SetClipboard = system.SetClipboard,
		GetClipboard = system.GetClipboard,
		Rand = math.randomf,
		LogF = logf,
		TypeOf = typex,
		GetFrameTime = timer.GetFrameTime,
		GetTime = timer.GetTime,
		CreateConVar = console.CreateVariable,
		GetConVarFloat = function(c)
			return c:Get()
		end,
		HSVToColor = function(h,s,v)
			return HSVToColor(h,s,v):Unpack()
		end,
		Color = Color,
		SetMaterial = surface.SetTexture,
		SetColor = function(r,g,b,a)
			R = r or 1
			G = g or 1
			B = b or 1
			A = a or 1

			if R > 1 then R = R/255 end
			if G > 1 then G = G/255 end
			if B > 1 then B = B/255 end
			if A > 1 then A = A/255 end

			surface.Color(R,G,B,A)
		end,
		CreateFont = surface.CreateFont,
		SetWhiteTexture = surface.SetWhiteTexture,
		DrawLine = surface.DrawLine,
		DrawRect = surface.DrawRect,
		DrawText = surface.DrawText,
		SetTextPos = surface.SetTextPos,
		SetFont = surface.SetFont,
		GetTextSize = surface.GetTextSize,
		GetScreenHeight = function()
			return select(2,surface.GetScreenSize())
		end,
		GetScreenWidth = function()
			return surface.GetScreenSize()
		end,
		GetMousePos = function()
			return window.GetMousePos():Unpack()
		end,
		SetCullClockWise = function(b) end,
		FindMaterial = Image,
		TranslateMatrix = function(x,y)
			surface.Translate(x or 0,y or 0)
		end,
		ScaleMatrix = function(x,y)
			surface.Scale(x or 0,y or 0)
		end,
		RotateMatrix = function(a)
			surface.Rotate(a)
		end,
		CreateMatrix =  function()
			render.PushWorldMatrix()
		end,
		PushMatrix = function() end,
		PopMatrix = render.PopWorldMatrix,
		OpenURL = function(str)
			os.execute("explorer "..str)
		end,
		SetAlphaMultiplier = surface.SetAlphaMultiplier
	}
end

EXT.CountChar = function(str,pattern)
	return select(2,str:gsub(pattern, ""))
end

function EXT.GetCharType(char)
	if char:find("%p") and char ~= "_" then
		return "punctation"
	elseif char:find("%s") then
		return "space"
	elseif char:find("%d") then
		return "digit"
	elseif char:find("%a") or char == "_" then
		return "letters"
	end

	return "unknown"
end

function EXT.FixIndices(tbl)
	local temp = {}
	local i = 1
	for k,v in pairs(tbl) do
		temp[i] = v
		tbl[k] = nil
		i = i+1
	end

	for k,v in ipairs(temp) do
		tbl[k] = v
	end
end

do
	META.DefaultFont = {
		Name = "markup_default",
		Data = {
			font       = "Tahoma",
			size       = 18,
			weight     = 600,
			antialias  = true,
			shadow     = true,
			prettyblur = 1,
			read_speed = 100,
		}
	}

	EXT.CreateFont(META.DefaultFont.Name, META.DefaultFont.Data)
end

do
	CHATHUD_TAGS = {}

	do
		CHATHUD_TAGS.click = {
			arguments = {},
			mouse = function(markup,self,button,press,x,y)
				if button == "button_1" and press then
					local str = ""
					for i = self.i+1,math.huge do
						local chunk = markup.chunks[i]
						if chunk.type == self.type or i > #markup.chunks then
							EXT.OpenURL(str)
							break
						elseif chunk.type == "string" then
							str = str..chunk.val
						end
					end
					return false
				end
			end,
			post_draw_chunks = function(markup,self,chunk)
				EXT.DrawLine(chunk.x,chunk.top,chunk.right,chunk.top)
			end
		}
		CHATHUD_TAGS.wrong = {
			arguments = {},
			post_draw_chunks = function(markup,self,chunk)
				local r,g,b,a = EXT.SetColor(1,0,0,1)
				
				for x = chunk.x, chunk.right do
					EXT.DrawLine(x,chunk.top+math.sin(x),x+1,chunk.top+math.sin(x))
				end

				EXT.SetColor(r,g,b,a)
			end
		}
		if gmod then
			local size = 8
			local _size = size/2
			CHATHUD_TAGS.chatbubble = {
				arguments = {},
				pre_draw = function(markup,self,x,y)
					local r,g,b,a = EXT.GetColor()
					local w,h = self.tag_width,self.tag_height
					draw.RoundedBox(size,x+_size,y-h/2-_size,w+size,h+size,Color(r,g,b,a))
				end,
				post_draw = function() end,
				get_size = function()
					return size,size
				end
			}
		end
		CHATHUD_TAGS.background = {
			arguments = {1,1,1,1},
			pre_draw = function(markup,self,x,y,r,g,b,a)
				local r,g,b,a = EXT.SetColor(r,g,b,a)
				local w, h = self.tag_width,self.tag_height
				
				EXT.SetWhiteTexture()
				EXT.DrawRect(x,y-h,w,h)
				EXT.SetColor(r,g,b,a)
			end,
			post_draw = function() end
		}
		CHATHUD_TAGS.mark = {
			arguments = {},
			post_draw_chunks = function(markup,self,chunk)
				local r, g, b, a = EXT.SetColor(1,1,0,0.25)
				EXT.SetWhiteTexture()
				EXT.DrawRect(chunk.x,chunk.y,chunk.w,chunk.h)
				EXT.SetColor(r,g,b,a)
			end
		}
		CHATHUD_TAGS.hsv = {
			arguments = {0,1,1},
			pre_draw = function(markup,self,x,y,h,s,v)
				local r,g,b = EXT.HSVToColor(h,s,v)
				EXT.SetColor(r,g,b,1)
			end
		}
		CHATHUD_TAGS.color = {
			arguments = {1,1,1,1},
			pre_draw = function(markup,self,x,y,r,g,b,a)
				EXT.SetColor(r,g,b,a)
			end
		}
		CHATHUD_TAGS.c = {
			arguments = {"FFFFFF"},
			init = function(markup,self,col)
				if self.R == nil then
					local col = parse_hexcolor(col)
					if not col then
						Msg("ChatColor failed parsing ")
						print(col)
						self.R = false
					else
						self.R = col.r
						self.G = col.g
						self.B = col.b
						self.A = col.a
					end
				end
			end,
			pre_draw = function(markup,self,x,y)
				EXT.SetColor(self.R or 255,self.G or 0,self.B or 255,self.A or 255)
			end
		}
		local blacklist = {
				creditslogo         = true,
				weaponiconsselected = true,
				hl2mptypedeath      = true,
				weaponicons         = true,
				nametags            = true,
				creditsoutrologos   = true,
		}
		CHATHUD_TAGS.font = {
			arguments = {"markup_default"},
			pre_draw = function(markup,self,x,y,font)
				if blacklist[font:lower()] or font == "NameTags" then return end
				EXT.SetFont(font)
			end,
			init = function(markup,self,font)
				if blacklist[font:lower()] then return end
				EXT.SetFont(font)
			end
		}
		CHATHUD_TAGS.texture = {
			arguments = {"error",{default=16,min=4,max=128}},
			init = function(markup,self,path)
				self.mat = EXT.FindMaterial(path)
			end,
			get_size = function(markup,self,path,size)
				return size,size
			end,
			pre_draw = function(markup,self,x,y,path,size)
				EXT.SetMaterial(self.mat)
				EXT.DrawRect(x,y,size,size)
			end
		}
		CHATHUD_TAGS.se = {
			arguments = {"error",{defau=27,min=4,max=128}},
			init = function(markup,self,name)
				self.name = name
				if GetSteamEmoticon(name) == false then
					self.name = nil
				end
			end,
			get_size = function(markup,self,path,size)
				return size,size
			end,
			pre_draw = function(markup,self,x,y,path,size)
				local dat = self.name
				dat = dat and GetSteamEmoticon(dat)
				if not dat then return end
				EXT.SetMaterial(dat)
				EXT.DrawRect(x,y,size,size)
			end
		}
		if not gmod then
			CHATHUD_TAGS.silkicon = {
				arguments = {"world",{default=1}},
				init = function(markup,self,path)
					self.mat = EXT.FindMaterial("textures/silkicons/"..path..".png")
				end,
				get_size = function(markup,self,path,size_mult)
					return 16,16
				end,
				pre_draw = function(markup,self,x,y,path)
					EXT.SetMaterial(self.mat)
					EXT.DrawRect(x,y,self.w,self.h)
				end
			}
		end
	end

	do
		local function detM2x2(m11,m12,m21,m22)
			return m11*m22-m12*m21
		end

		local function mulM2x2V2(m11,m12,m21,m22,v1,v2)
			return v1*m11+v2*m12,v1*m21+v2*m22
		end

		local function normalizeV2(x,y)
			local length = math.sqrt(x*x+y*y)
			return x/length,y/length
		end

		local function scaleV2(v1,v2,k)
			return v1*k,v2*k
		end

		local function eigenvector2(l,a,d)
			if a - l == 0 then return 1,0 end
			if     d == 0 then return 0,1 end

			return normalizeV2(-d/(a-l),1)
		end

		local function orthonormalM2x2ToVMatrix(m11,m12,m21,m22)
			local det = detM2x2(m11,m12,m21,m22)

			if det < 0 then
				EXT.ScaleMatrix(1,-1)
			end

			local angle = math.atan2(m21,m11)
			EXT.RotateMatrix(math.deg(angle))
		end

		CHATHUD_TAGS.translate = {
			arguments = {0,0},
			pre_draw = function(markup,self,x,y,dx,dy)
				EXT.CreateMatrix()
				EXT.TranslateMatrix(dx,dy)
				EXT.PushMatrix()
			end,
			post_draw = function()
				EXT.PopMatrix()
			end
		}

		CHATHUD_TAGS.scale = {
			arguments = {1,nil},
			init = function() end,
			pre_draw = function(markup,self,x,y,scaleX,scaleY)
				--EXT.CreateMatrix()
				
				if scaleY == nil then scaleY = scaleX end

				CHATHUD_TAGS.matrix.pre_draw(markup,self,x,y,scaleX,0,0,scaleY,0,0)
				
				--[[self.matrixDeterminant = scaleX*scaleY

				if math.abs(self.matrixDeterminant) > 1 then
					scaleX,scaleY = scaleV2(scaleX,scaleY,1/math.sqrt(self.matrixDeterminant))
				end

				local centerY = y-self.tag_height/2

				EXT.TranslateMatrix(x,centerY)
					EXT.ScaleMatrix(scaleX,scaleY)

					if scaleX < 0 then
						EXT.TranslateMatrix(-self.tag_width,0)
					end
				EXT.TranslateMatrix(-x,-centerY)
				EXT.PushMatrix()
				EXT.SetCullClockWise(self.matrixDeterminant < 0)]]
			end,
			post_draw = function(markup,self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end
				EXT.PopMatrix()
			end
		}
		CHATHUD_TAGS.size = {
			arguments = {1},
			pre_draw = function(markup,self,x,y,size)
				CHATHUD_TAGS.scale.pre_draw(markup,self,x,y,size,size)
			end,
			post_draw = function(markup,self)
				CHATHUD_TAGS.scale.post_draw(markup,self,x,y,size,size)
			end
		}
		CHATHUD_TAGS.rotate = {
			arguments = {45},
			pre_draw = function(markup,self,x,y,deg)
				EXT.CreateMatrix()

				local center_x = self.tag_center_x
				local center_y = self.tag_center_y
				
				EXT.TranslateMatrix(center_x,center_y)
					EXT.RotateMatrix(deg)
				EXT.TranslateMatrix(-center_x,-center_y)
				EXT.PushMatrix()
			end,
			post_draw = function()
				EXT.PopMatrix()
			end
		}
		CHATHUD_TAGS.matrixez = {
			arguments = {0,0,1,1,0},
			pre_draw = function(markup,self,x,y,X,Y,scaleX,scaleY,angleInDegrees)
				self.matrixDeterminant = scaleX*scaleY

				if math.abs(self.matrixDeterminant) > 10 then
					scaleX,scaleY = normalizeV2(scaleX,scaleY)
					scaleX,scaleY = scaleV2(scaleX,scaleY,10)
				end

				local centerX = self.tag_center_x
				local centerY = self.tag_center_y

				EXT.CreateMatrix()
				
				EXT.TranslateMatrix(x,centerY)
					EXT.TranslateMatrix(X,Y)
					EXT.ScaleMatrix(scaleX,scaleY)
					if scaleX < 0 then
						EXT.TranslateMatrix(-self.tag_width,0)
					end
					if angleInDegrees ~= 0 then
						EXT.TranslateMatrix(centerX)
							EXT.RotateMatrix(angleInDegrees)
						EXT.TranslateMatrix(-centerX)
					end
				EXT.TranslateMatrix(x,-centerY)
				EXT.PushMatrix()
				EXT.SetCullClockWise(self.matrixDeterminant < 0)
			end,
			post_draw = function(markup, self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end
				EXT.PopMatrix()
			end
		}
		CHATHUD_TAGS.matrix = {
			arguments = {1,0,0,1,0,0},
			pre_draw = function(markup,self,x,y,a11,a12,a21,a22,dx,dy)
				local b11  = a11*a11+a21*a21
				local b12  = a11*a12+a21*a22
				local b21  = a12*a11+a22*a21
				local b22  = a12*a12+a22*a22
				local trB  = b11+b22
				local detB = detM2x2(b11,b12,b21,b22)
				local sqrtInside  = trB*trB-4*detB
				local eigenvalue1 = 0.5*(trB+math.sqrt(sqrtInside))
				local eigenvalue2 = 0.5*(trB-math.sqrt(sqrtInside))
				local q211,q221   = eigenvector2(eigenvalue1,b11,b12)
				local q212,q222   = eigenvector2(eigenvalue2,b11,b12)
				
				if eigenvalue1 == eigenvalue2 then
					q212,q222 = q221,-q211
				end
				
				local scaleX = math.sqrt(eigenvalue1)
				local scaleY = math.sqrt(eigenvalue2)

				local detQ2     = q211*q222-q212*q221
				local q111,q121 = mulM2x2V2(a11,a12,a21,a22,q211,q221)
				local q112,q122 = mulM2x2V2(a11,a12,a21,a22,q212,q222)
				
				q111,q121 = scaleV2(q111,q121,(scaleX ~= 0) and (1/scaleX) or 0)

				if scaleY == 0 then
					q112,q122 = q121,-q111
				else
					q112,q122 = scaleV2(q112,q122,(scaleY ~= 0) and (1/scaleY) or 0)
				end
				
				q212,q221 = q221,q212

				self.matrixDeterminant = detM2x2(a11,a12,a21,a22)
				
				EXT.CreateMatrix()

				EXT.TranslateMatrix(x,y)
					EXT.TranslateMatrix(dx,dy)
					
					orthonormalM2x2ToVMatrix(q211,q212,q221,q222)
						EXT.ScaleMatrix(scaleX,scaleY)
					orthonormalM2x2ToVMatrix(q111,q112,q121,q122)
				EXT.TranslateMatrix(-x,-y)
				EXT.PushMatrix()
				EXT.SetCullClockWise(self.matrixDeterminant < 0)
			end,
			post_draw = function(markup, self)
				if self.matrixDeterminant < 0 then
					EXT.SetCullClockWise(false)
				end
				
				EXT.PopMatrix()
			end
		}

		CHATHUD_TAGS.i = {
			arguments = {},
			init = function() end,
			pre_draw = function(markup,self,x,y)
				CHATHUD_TAGS.translate.pre_draw(markup,self,x,y,-3,0)
				CHATHUD_TAGS.matrix   .pre_draw(markup,self,x,y,1,0,0.5,1,0,0)
			end,
			post_draw = function(markup,self)
				CHATHUD_TAGS.translate.post_draw(markup,self)
				CHATHUD_TAGS.matrix   .post_draw(markup,self)
			end
		}
	end
end

function META:Clear()
	self.chunks = {}
	self:Invalidate()
end

function META:SetTable(tbl,tags)
	self.Table = tbl

	self:Clear()

	for k,v in ipairs(tbl) do
		self:Add(v,tags)
	end
end

function META:AddTable(tbl,tags)
	for k,v in ipairs(tbl) do
		self:Add(v,tags)
	end
end

function META:BeginLifeTime(time)
	table.insert(self.chunks,{
		type = "start_fade",
		val  = os.clock()+time
	})
end

function META:EndLifeTime()
	table.insert(self.chunks,{
		type = "end_fade",
		val  = true
	})
end

function META:AddTagStopper()
	table.insert(self.chunks,{
		type = "tag_stopper",
		val  = true
	})
end

function META:AddColor(color)
	table.insert(self.chunks,{
		type = "color",
		val  = color
	})
	self.need_layout = true
end

function META:AddString(str,tags)
	str = tostring(str)

	if tags then
		for k,v in pairs(self:ParseTags(str)) do
			table.insert(self.chunks,v)
		end
	else
		table.insert(self.chunks,{
			type = "string",
			val  = str
		})
	end

	self.need_layout = true
end

function META:AddFont(font)
	table.insert(self.chunks,{
		type = "font",
		val  = font
	})
	self.need_layout = true
end

function META:Add(var,tags)
	local t = EXT.TypeOf(var)

	if t == "color" then
		self:AddColor(var)
	elseif t == "string" or t == "number" then
		self:AddString(var,tags)
	elseif t == "table" and var.type and var.val then
		table.insert(self.chunks,var)
	elseif t ~= "cdata" then
		EXT.LogF("tried to parse unknown type %q", t)
	end

	self.need_layout = true
end

function META:TagPanic()
	for k, v in pairs(self.chunks) do
		if v.type == "custom" then
			v.panic = true
		end
	end
end

local time_speed  = 1
local time_offset = 0
local panic       = false

local function call_tag_func(self,chunk,name,...)
	if not chunk.val.tag then return end

	if chunk.type == "custom" and not chunk.panic then
		local func = chunk.val.tag and chunk.val.tag[name]
		
		if func then
			local args = {self,chunk,...}
			
			for i,t in pairs(chunk.val.tag.arg_types) do
				local val = chunk.val.args[i]
			
				if type(val) == "function" then
					local ok,v = pcall(val,chunk.exp_env)
					
					if ok then
						val = v
					end
				end
				
				if type(val) ~= t then
					val = chunk.val.tag.arguments[k]
					
					if type(v) == "table" then
						val = v.default
					end
				end
				
				table.insert(args,val)
			end
			
			args = {xpcall(func,debug.Trace or mmyy.OnError,unpack(args))}

			if not args[1] then
				EXT.LogF("tag error %s",args[2])
			end

			return unpack(args)
		end
	end
end

do
	local function parse_tag_arguments(self,arg_line)
    	local out = {}
        local str = {}
        local in_lua = false
        
        for i,char in pairs(utf8.totable(arg_line)) do
            if char == "[" then
				in_lua = true
			elseif in_lua and char == "]" then
				in_lua = false
				local exp = table.concat(str,"")
				local ok,func = expression.Compile(exp)
				if ok then
					table.insert(out,func)
				else
                    EXT.LogF(exp)
					EXT.LogF("markup expression error: %s",func)
				end
				str = {}
			elseif char == "," and not in_lua then
				if #str > 0 then
					table.insert(out,table.concat(str, ""))
					str = {}
				end
			else
				table.insert(str,char)
			end
        end

		if #str > 0 then
			table.insert(out,table.concat(str,""))
			str = {}
		end
		
		for k,v in pairs(out) do
			if tonumber(v) then
				out[k] = tonumber(v)
			end
		end
		
		return out
	end

	function META:ParseTags(str)
		str = tostring(str)
	
		str = str:gsub("<rep=(%d+)>(.-)</rep>",function(count, str)
			count = math.min(math.max(tonumber(count),1),500)
			
			if #str:rep(count):gsub("<(.-)=(.-)>",""):gsub("</(.-)>",""):gsub("%^%d","") > 500 then
				return "rep limit reached"
			end
			
			return str:rep(count)
		end)
		
		local chunks         = {}
		local found          = false
		local in_tag         = false
		local current_string = {}
		local current_tag    = {}
		local last_font
		local last_color

		for i,char in pairs(utf8.totable(str)) do
			if char == "<" then
				if current_string then
					table.insert(chunks,{
						type = "string",
						val  = table.concat(current_string, "")
					})
				end
				
				current_tag = {}
				in_tag      = true
			elseif char == ">" and in_tag then
				if current_tag then
					local tag_str         = table.concat(current_tag,"")..">"
					local tagType,arg_str = tag_str:match("<(.-)=(.+)>")
					local stop_tag        = false

					if not tagType or not CHATHUD_TAGS[tagType] then
						tagType = tag_str:match("<(.-)>")
					end

					if not tagType or not CHATHUD_TAGS[tagType] then
						tagType  = tag_str:match("</(.-)>")
						stop_tag = true
					end

					local info          = CHATHUD_TAGS[tagType]
					local is_expression = false

					if info then
						local args = {}
						
						if not stop_tag then
							info.arg_types = {}
							args           = parse_tag_arguments(self,arg_str or "")

							for i = 1,#info.arguments do
								local arg     = args[i]
								local default = info.arguments[i]
								local t       = type(default)
								
								info.arg_types[i] = t == "table" and "number" or t

								if t == "number" then
									local num = tonumber(arg)

									if not num and type(arg) == "function" then
										is_expression = true
										num = arg
									end

									args[i] = num or default
								elseif t == "string" then
									if not arg or arg == "" then
										arg = default
									end

									args[i] = arg
								elseif t == "table" then
									if default.min or default.max or default.default then
										local num = tonumber(arg)

										if num then
											if default.min and default.max then
												args[i] = math.min(math.max(num,default.min),default.max)
											elseif default.min then
												args[i] = math.min(num,default.min)
											elseif default.max then
												args[i] = math.max(num,default.max)
											end
										else
											if type(arg) == "function" then
												if default.min and default.max then
													args[i] = function(...) return math.min(math.max(arg(...) or default.default,default.min),default.max) end
												elseif default.min then
													args[i] = function(...) return math.min(arg(...) or default.default,default.min) end
												elseif default.max then
													args[i] = function(...) return math.max(arg(...) or default.default,default.max) end
												end
												is_expression = true
											else
												args[i] = default.default
											end
										end
									end
								end
							end
							
							for i = #info.arguments+1,#args do
								info.arg_types[i] = type(args[i])
							end
						end
						
						found = true
						
						if not is_expression and tagType == "font" then
							if stop_tag then
								if last_font then
									table.insert(chunks,{
										type = "font",
										val  = last_font
									})
								end
							else
								table.insert(chunks, {
									type = "font",
									val  = args[1]
								})
								
								last_font = args[1]
							end
						elseif not is_expression and tagType == "color" then
							if stop_tag then
								if last_color then
									table.insert(chunks,{
										type = "color",
										val  = Color(unpack(last_color))
									})
								end
							else
								table.insert(chunks,{
									type = "color",
									val  = Color(unpack(args))
								})
								
								last_color = args
							end
						else
							table.insert(chunks,{
								type = "custom",
								val = {
									tag      = info,
									type     = tagType,
									args     = args,
									stop_tag = stop_tag
								}
							})
						end
					end
				end

				current_string = {}
				in_tag         = false
			end

			if in_tag then
				table.insert(current_tag,char)
			elseif char ~= ">" then
				table.insert(current_string,char)
			end
		end

		if found then
			table.insert(chunks,{
				type = "string",
				val  = table.concat(current_string,"")
			})
		else
			chunks = {
				{
					type = "string",
					val  = str
				}
			}
		end
	
		for i,chunk in ipairs(chunks) do
			if chunk.type == "custom" and CHATHUD_TAGS[chunk.val.type].modify_text then
				local start_chunk = chunk
				local func        = CHATHUD_TAGS[start_chunk.val.type].modify_text
				
				for i=i,#chunks do
					local chunk = chunks[i]
					
					if chunk.type == "string" then
						chunk.val = func(self,chunk,chunk.val,unpack(start_chunk.val.args)) or chunk.val
					end
					
					if chunk.type == "tag_stopper" or (chunk.type == "custom" and chunk.val.type == start_chunk.val.type and chunk.val.stop_tag) then
						break
					end
				end
			end
		end
		
		return chunks
	end
end

do
	local function prepare_chunks(self)
		local temp       = {}
		local old_chunks = {}
		local skipped    = 0

		for i,chunk in ipairs(self.chunks) do
			if chunk.internal or chunk.type == "string" and chunk.val == "" then goto continue_ end

			local old = chunk.old_chunk

			if old then
				old.old_chunk = nil

				if not old_chunks[old] then
					table.insert(temp,old)
					old_chunks[old] = true
				end
			else
				table.insert(temp,chunk)
			end

			::continue_::
		end
		
		table.insert(temp,1,{
			type     = "font",
			val      = self.DefaultFont.Name,
			internal = true
		})
		
		table.insert(temp,1,{
			type     = "color",
			val      = EXT.Color(255,255,255),
			internal = true
		})
		
		for i=1,3 do
			table.insert(temp,{
				type     = "string",
				val      = "",
				internal = true
			})
		end

		return temp
	end
	
	local function split_by_space_and_punctation(self,chunks)
		local out = {}
		
		for i,chunk in ipairs(chunks) do
			if chunk.type == "string" and chunk.val:find("%s") and not chunk.internal then
				local str = {}

				for i,char in ipairs(utf8.totable(chunk.val)) do
					if char:find("%s") then
						if #str ~= 0 then
							table.insert(out,{
								type      = "string",
								val       = table.concat(str),
								old_chunk = chunk
							})
							
							if table.clear then
								table.clear(str)
							else
								str = {}
							end
						end

						if char == "\n" then
							table.insert(out,{
								type      = "newline",
								old_chunk = chunk
							})
						else
							table.insert(out,{
								type       = "string",
								val        = char,
								whitespace = true,
								old_chunk  = chunk
							})
						end
					else
						table.insert(str,char)
					end
				end

				if #str ~= 0 then
					table.insert(out,{
						type      = "string",
						val       = table.concat(str),
						old_chunk = chunk
					})
				end
			else
				table.insert(out,chunk)
			end
		end
		
		return out
	end

	local function get_size_info(self, chunks)
		for i,chunk in ipairs(chunks) do
			if chunk.type == "font" then
				EXT.SetFont(chunk.val)
			elseif chunk.type == "string" then
				local w,h = EXT.GetTextSize(chunk.val)

				chunk.w,chunk.h = w,h

				if chunk.internal then
					chunk.w      = 0
					chunk.h      = 0
					chunk.real_h = h
					chunk.real_w = w
				end
			elseif chunk.type == "newline" then
				local w, h = EXT.GetTextSize("|")

				chunk.w = w
				chunk.h = h
			elseif chunk.type == "custom" and not chunk.val.stop_tag  then
				local ok,w,h = call_tag_func(self,chunk,"get_size")
				
				chunk.w = w
				chunk.h = h

				chunk.pre_called = false
			end
			
			chunk.x = chunk.x or 0
			chunk.y = chunk.y or 0
			chunk.w = chunk.w or 0
			chunk.h = chunk.h or 0
		end
		
		return chunks
	end
	
	local function solve_max_width(self,chunks)
		local current_x,current_y = 0,0
		local chunk_height        = 0

		for i,chunk in ipairs(chunks) do
			local newline = chunks[i-1] and chunks[i-1].type == "newline"
			
			if chunk.h > chunk_height then
				chunk_height = chunk.h
			end
			
			if newline or (self.LineWrap and current_x+chunk.w >= self.MaxWidth) then
				current_x    = 0
				current_y    = current_y+chunk_height
				chunk_height = chunk.h
			end

			chunk.x,chunk.y = current_x,current_y
			current_x       = current_x+chunk.w
		end
		
		return chunks
	end
	
	local function string_wrap(self,chunks)
		local out = {}
		for i,chunk in ipairs(chunks) do
			local split = false
			if chunk.type == "font" then
				EXT.SetFont(chunk.val)
			elseif chunk.type == "string" then
				if self.LineWrap and chunk.x+chunk.w >= self.MaxWidth then
					local current_x,current_y = chunk.x,chunk.y
					local chunk_height        = 0
					local str                 = ""

					for i,char in ipairs(utf8.totable(chunk.val)) do
						local w,h = EXT.GetTextSize(char)

						if h > chunk_height then
							chunk_height = h
						end

						str = str..char
						current_x = current_x + w

						if current_x+w > self.MaxWidth then
							table.insert(out,{
								type      = "string",
								val       = str,
								x         = 0,
								y         = current_y,
								w         = current_x,
								h         = chunk_height,
								old_chunk = chunk
							})
							
							current_y    = current_y+chunk_height
							current_x    = 0
							chunk_height = 0
							split        = true
							str          = ""
						end
					end

					if split then
						table.insert(out,{
							type = "string",
							val       = str,
							x         = 0,
							y         = current_y,
							w         = current_x,
							h         = chunk_height,
							old_chunk = chunk
						})
					end
				end
			end

			if not split then
				chunk.old_chunk = chunk
				table.insert(out,chunk)
			end
		end
		
		return out
	end
	
	local function solve_max_width2(self,chunks)
		if self.LineWrap then
			local current_y    = 0
			local last_y       = 0
			local chunk_height = 0
			local line         = {}
			
			for i,chunk in ipairs(chunks) do
				if chunk.h > chunk_height then
					chunk_height = chunk.h
				end
			
				if last_y ~= chunk.y then
					for k,v in pairs(line) do
						v.y     = current_y
						line[k] = nil
					end
					current_y = current_y+chunk_height
					chunk_height = 0
				end
				
				last_y = chunk.y
				table.insert(line,chunk)
			end
		end
		
		return chunks
	end
	
	local function newline_break(self,chunks)
		local current_x,current_y = 0,0

		for i,chunk in ipairs(chunks) do
			local newline = chunks[i-1] and chunks[i-1].type == "newline"

			if newline and chunk.type == "string" and not chunk.whitespace then
				if newline or current_x+chunk.w >= self.MaxWidth then
					current_x = 0
					current_y = chunk.y
				end

				chunk.x   = current_x
				chunk.y   = current_y
				current_x = current_x+chunk.w
			end
		end
		
		return chunks
	end
	
	local function store_tag_info(self,chunks)
		local line   = 0
		local width  = 0
		local height = 0
		local last_y

		local font  = self.DefaultFont.Name
		local color = Color(1,1,1,1)

		local function build_chars(chunk)
			if not chunk.chars then
				EXT.SetFont(chunk.font)
				chunk.chars = {}
				local width = 0
				local str   = chunk.val

				if str == "" and chunk.internal then
					str = " "
				end

				for i,char in ipairs(utf8.totable(str)) do
					local char_width,char_height = EXT.GetTextSize(char)
					local x = chunk.x+width
					local y = chunk.y

					chunk.chars[i] = {
						x     = x,
						y     = chunk.y,
						w     = char_width,
						h     = char_height,
						right = x+char_width,
						top   = y+char_height,
						char  = char,
						i     = i,
						chunk = chunk
					}

					chunk.chars[i].unicode = #char > 1
					chunk.chars[i].length = #char

					width = width+char_width
				end

				if str == " " and chunk.internal then
					chunk.chars[1].char  = ""
					chunk.chars[1].w     = 0
					chunk.chars[1].h     = 0
					chunk.chars[1].x     = 0
					chunk.chars[1].y     = 0
					chunk.chars[1].top   = 0
					chunk.chars[1].right = 0
				end
			end
		end

		local chunk_line  = {}
		local line_height = 0
		local line_width  = 0
		
		self.chars = {}
		self.lines = {}

		local char_line     = 1
		local char_line_pos = 0
		local char_line_str = {}

		for i,chunk in ipairs(chunks) do
			chunk.exp_env = {
				i    = chunk.real_i,
				w    = chunk.w,
				h    = chunk.h,
				x    = chunk.x,
				y    = chunk.y,
				rand = math.random()
			}

			if chunk.type == "font" then
				font = chunk.val
			elseif chunk.type == "color" then
				color = chunk.val
			elseif chunk.type == "string" then
				chunk.font = font
				chunk.color = color
			end

			local w = chunk.x+chunk.w
			if w > width then
				width = w
			end

			local h = chunk.y+chunk.h
			if h > height then
				height = h
			end

			if chunk.h > line_height then
				line_height = chunk.h
			end

			line_width = line_width+chunk.w

			if chunk.y ~= last_y then
				line   = line+1
				last_y = chunk.y

				for i,chunk in pairs(chunk_line) do
					chunk.line_height = line_height
					chunk.line_width  = line_width
					chunk_line[i]     = nil
				end
				
				line_height = chunk.h
				line_width  = chunk.w
			end
			
			chunk.line        = line
			chunk.build_chars = build_chars
			chunk.i           = i
			chunk.real_i      = chunk.real_i or i

			if chunk.type == "custom" and not chunk.val.stop_tag then
				if CHATHUD_TAGS[chunk.val.type].post_draw or CHATHUD_TAGS[chunk.val.type].post_draw_chunks or CHATHUD_TAGS[chunk.val.type].pre_draw_chunks then
					local current_width  = 0
					local current_height = 0
					local width          = 0
					local height         = 0
					local last_y
					
					local tag_type    = chunk.val.type
					local start_chunk = chunk
					local line        = {}
					
					local start_found = 1
					local stops = {}
					
					for i = i+1,math.huge do
						local chunk = chunks[i]
						
						if chunk then
							if not last_y then last_y = chunk.y end
								
							current_width = current_width+chunk.w

							if chunk.h > current_height then
								current_height = chunk.h
							end
							
							if last_y ~= chunk.y then
								if current_width > width then
									width = current_width
								end
								
								height         = height+current_height
								current_height = 0
								current_width  = 0
								last_y         = chunk.y
							end
							
							chunk.i = i

							if chunk.type == "tag_stopper" then
								break
							elseif chunk.type == "custom" and chunk.val.type == tag_type then
								if not chunk.val.stop_tag then
									start_found = start_found+1
								else
									table.insert(stops,chunk)
									if start_found == 1 then
										break
									end
								end
							else
								table.insert(line,chunk)
							end
						else
							break
						end
					end

					height = height+current_height
					
					if current_width > width then
						width = current_width
					end
					
					local stop_chunk = stops[start_found] or line[#line]
					
					if stop_chunk then
						stop_chunk.chunks_inbetween = line
						stop_chunk.start_chunk      = chunk
						stop_chunk.tag_stop_draw    = true
						
						local center_x = chunk.x+width /2
						local center_y = chunk.y+height/2
						
						chunk.tag_start_draw   = true
						chunk.tag_center_x     = center_x
						chunk.tag_center_y     = center_y
						chunk.tag_height       = height
						chunk.tag_width        = width
						chunk.chunks_inbetween = line

						for i,chunk in pairs(line) do
							chunk.tag_center_x     = center_x
							chunk.tag_center_y     = center_y
							chunk.tag_height       = height
							chunk.tag_width        = width
							chunk.chunks_inbetween = line
						end
					end
				else
					chunk.tag_start_draw = true
				end
			end
			
			do
				chunk.chars = nil

				if chunk.type == "string" then
					chunk:build_chars()
					
					for i2,char in pairs(chunk.chars) do
						table.insert(self.chars,{
							chunk    = chunk,
							i        = i,
							str      = char.char,
							data     = char,
							y        = char_line,
							x        = char_line_pos,
							unicode  = char.unicode,
							length   = char.length,
							internal = char.internal
						})

						char_line_pos = char_line_pos+1
						table.insert(char_line_str,char.char)
					end

				elseif chunk.type == "newline" then
					local data = {}

					data.w     = chunk.w
					data.h     = chunk.h
					data.x     = chunk.x
					data.y     = chunk.y
					data.right = chunk.x+chunk.w
					data.top   = chunk.y+chunk.h

					table.insert(self.chars,{
						chunk = chunk,
						i     = i,
						str   = "\n",
						data  = data,
						y     = char_line,
						x     = char_line_pos
					})
					
					char_line     = char_line+1
					char_line_pos = 0

					table.insert(self.lines,table.concat(char_line_str,""))
					
					if table.clear then
						table.clear(char_line_str)
					else
						for i=1,#char_line_str do
							char_line_str[i] = nil
						end
					end
				end

				chunk.tag_center_x = chunk.tag_center_x or 0
				chunk.tag_center_y = chunk.tag_center_y or 0
				chunk.tag_width    = chunk.tag_width    or 0
				chunk.tag_height   = chunk.tag_height   or 0
			end

			table.insert(chunk_line,chunk)
		end

		for i,chunk in pairs(chunk_line) do
			chunk.line_height = line_height
			chunk.line_width  = line_width
			chunk_line[i]     = nil
		end
		
		table.insert(self.lines,table.concat(char_line_str,""))
		
		self.text       = table.concat(self.lines, "\n")
		self.line_count = line
		self.width      = width
		self.height     = height
	end

	local function align_y_axis(self,chunks)
		for _,chunk in ipairs(chunks) do
			if chunk.type ~= "newline" then
				chunk.y = chunk.y-chunk.h+chunk.line_height
			end
			
			chunk.right = chunk.x+chunk.w
			chunk.top   = chunk.y+chunk.h
		end
		
		local chunk = chunks[#chunks-1]
		
		if chunk and chunk.type == "newline" then
			chunk.y = chunk.y+chunk.line_height+chunk.h
			chunk.x = 0
		end
	end
		
	function META:Invalidate()
		local chunks = prepare_chunks(self)
		chunks = split_by_space_and_punctation(self,chunks)
		chunks = get_size_info(self,chunks)
		chunks = solve_max_width(self,chunks)
		chunks = string_wrap(self,chunks)
		chunks = solve_max_width(self,chunks)
		chunks = newline_break(self,chunks)
		
		store_tag_info(self,chunks)
		align_y_axis(self,chunks)
		
		self.chunks = chunks

		if self.caret_pos then
			self:SetCaretPos(self.caret_pos.x,self.caret_pos.y)
		else
			self:SetCaretPos(0,0)
		end

		if self.select_start then
			self:SelectStart(self.select_start.x,self.select_start.y)
		end

		if self.select_stop then
			self:SelectStop(self.select_stop.x,self.select_stop.y)
		end

		if self.OnInvalidate then
			self:OnInvalidate()
		end
	end
end

function META:GetNextCharacterClassPos(delta,next_space)
	if next_space == nil then
		next_space = not self.caret_shift_pos
	end

	local pos = self.caret_pos.i

	if delta > 0 then
		pos = pos+1
	end

	if delta > 0 then
		if pos > 0 and self.chars[pos-1] then
			local type = EXT.GetCharType(self.chars[pos-1].str)

			while pos > 0 and self.chars[pos] and EXT.GetCharType(self.chars[pos].str) == type do
				pos = pos+1
			end
		end

		if pos >= #self.chars then
			return pos,1
		end

		if next_space then
			while pos > 0 and self.chars[pos] and EXT.GetCharType(self.chars[pos].str) == "space" and self.chars[pos].str ~= "\n" do
				pos = pos+1
			end
		end

		return self.chars[pos-1].x,self.chars[pos-1].y
	else
		if next_space then
			while pos > 1 and EXT.GetCharType(self.chars[pos-1].str) == "space" and self.chars[pos-1].str ~= "\n" do
				pos = pos-1
			end
		end

		if self.chars[pos-1] then
			local type = EXT.GetCharType(self.chars[pos-1].str)

			while pos > 1 and EXT.GetCharType(self.chars[pos-1].str) == type do
				pos = pos-1
			end
		end

		if pos == 1 then
			return 0,1
		end

		return self.chars[pos+1].x,self.chars[pos+1].y
	end
end

function META:InsertString(str,skip_move,start_offset,stop_offset)
	start_offset = start_offset or 0
	stop_offset  = stop_offset  or 0
	
	local sub_pos = self:GetCaretSubPos()

	self:DeleteSelection(true)
	
	do
		local x,y = self.caret_pos.x,self.caret_pos.y

		for i=1,start_offset do
			x = x-1

			if x <= 0 then
				y = y-1
				x = utf8.length(self.lines[y])
			end
		end

		self:SelectStart(x,y)

		local x,y = self.caret_pos.x,self.caret_pos.y

		for i = 1,stop_offset do
			x = x+1

			if x >= utf8.length(self.lines[y]) then
				y = y+1
				x = 0
			end
		end

		self:SelectStop(x,y)
		self:DeleteSelection(true)
	end

	self.text = utf8.sub(self.text,1,sub_pos-1)..str..utf8.sub(self.text,sub_pos)

	do
		local sub_pos = self.caret_pos.char.data.i
		local chunk   = self.caret_pos.char.chunk

		if chunk.internal or chunk.type ~= "string" and ((self.chunks[chunk.i-1] and self.chunks[chunk.i-1].type ~= "string") or (self.chunks[chunk.i+1] and self.chunks[chunk.i+1].type ~= "string")) then
			table.insert(self.chunks,chunk.internal and #self.chunks or chunk.i,{
				type = "string",
				val  = str
			})
			self:Invalidate()
		else
			do
				local pos = chunk.i

				while chunk.type ~= "string" and pos > 1 do
					pos   = pos - 1
					chunk = self.chunks[pos]
				end
			end

			if chunk.type == "string" then
				if not sub_pos then
					sub_pos = #chunk.chars+1
				end

				chunk.val = utf8.sub(chunk.val,1,sub_pos-1)..str..utf8.sub(chunk.val,sub_pos)
			else
				table.remove(self.chunks,chunk.i)
			end
		end

		self:Invalidate()
	end

	if not skip_move then
		local x = self.caret_pos.x+utf8.length(str)
		local y = self.caret_pos.y+EXT.CountChar(str,"\n")

		if self.caret_pos.char.str == "\n" then
			self.move_caret_right = true
			x = x+1
		end

		self.real_x = x
		
		self:SetCaretPos(x,y)
	end

	self:InvalidateEditedText()
	self.caret_shift_pos = nil
end

function META:Backspace()
	local sub_pos = self:GetCaretSubPos()

	local prev_line = self.lines[self.caret_pos.y-1]

	if not self:DeleteSelection() and sub_pos ~= 1 then
		if self.ControlDown then
			local x,y = self:GetNextCharacterClassPos(-1,true)
			x = x-1

			if x <= 0 and #self.lines > 1 then
				x = math.huge
				y = y-1
			end

			self:SelectStart(self.caret_pos.x,self.caret_pos.y)
			self:SelectStop(x,y)
			self:DeleteSelection()

			self.real_x = x
		else
			local x, y = self.caret_pos.x,self.caret_pos.y

			if self.chars[self.caret_pos.i-1] then
				x = self.chars[self.caret_pos.i-1].x
				y = self.chars[self.caret_pos.i-1].y

				self:SelectStart(self.caret_pos.x,self.caret_pos.y)
				self:SelectStop(x,y)

				self:DeleteSelection()
			end
		end
	end

	self:InvalidateEditedText()
end

function META:Delete()
	local line = self.lines[self.caret_pos.y+1]
	local sub_pos = self:GetCaretSubPos()

	if not self:DeleteSelection() then
		local ok = false
		
		if self.ControlDown then
			local x,y = self:GetNextCharacterClassPos(1,true)

			x = x+1

			self:SelectStart(self.caret_pos.x,self.caret_pos.y)
			self:SelectStop(x,y)

			ok = self:DeleteSelection()
		end

		if not ok then
			local x,y = self.caret_pos.x,self.caret_pos.y

			if self.chars[self.caret_pos.i+1] then
				x = self.chars[self.caret_pos.i+1].x
				y = self.chars[self.caret_pos.i+1].y

				self:SelectStart(self.caret_pos.x,self.caret_pos.y)
				self:SelectStop(x,y)
				self:DeleteSelection()
			end
		end
	end

	self:InvalidateEditedText()
end

function META:InvalidateEditedText()
	if self.text ~= self.last_text and self.OnTextChanged then
		self:OnTextChanged(self.text)
		self.last_text = self.text
	end
end

function META:GetSubPosFromPos(x,y)
	if x == math.huge and y == math.huge then
		return #self.chars
	end

	if x == 0 and y == 0 then
		return 0
	end

	for sub_pos,char in pairs(self.chars) do
		if char.x == x and char.y == y then
			return sub_pos
		end
	end

	if x == math.huge then
		for sub_pos,char in pairs(self.chars) do
			if char.y == y and char.str == "\n" then
				return sub_pos-1
			end
		end
		return self.chars[#self.chars]
	end

	if y == math.huge then
		for i = 1,self.chars do
			i = -i+#self.chars
			local char = self.chars[i]

			if char.x == x then
				return sub_pos-1
			end
		end
	end

	return 0
end

function META:Indent(back)
	local sub_pos = self:GetCaretSubPos()

	local select_start = self:GetSelectStart()
	local select_stop = self:GetSelectStop()

	if select_start and select_start.y ~= select_stop.y then
		self:SelectStart(0,select_start.y)
		self:SelectStop(math.huge,select_stop.y)
		self:SetCaretPos(select_stop.x,select_stop.y)

		local select_start = self:GetSelectStart()
		local select_stop  = self:GetSelectStop()

		local text = utf8.sub(self.text,select_start.sub_pos,select_stop.sub_pos)

		if back then
			if text:sub(1, 1) == "\t" then
				text = text:sub(2)
			end
			text = text:gsub("\n\t","\n")
		else
			text = "\t"..text
			text = text:gsub("\n","\n\t")
			
			if text:sub(-1) == "\t" then
				text = text:sub(0,-2)
			end
		end

		self.text = utf8.sub(self.text,1,select_start.sub_pos-1)..text..utf8.sub(self.text,select_stop.sub_pos+1)

		do
			for i = select_start.char.chunk.i-1,select_stop.char.chunk.i-1 do
				local chunk = self.chunks[i]
				if chunk.type == "newline" then
					if not back and self.chunks[i+1].type ~= "string" then
						table.insert(self.chunks,i+1,{
							type = "string",
							val  = "\t"
						})
					else
						local pos = i

						while chunk.type ~= "string" and pos < #self.chunks do
							chunk = self.chunks[pos]
							pos = pos+1
						end

						if back then
							if chunk.val:sub(1,1) == "\t" then
								chunk.val = chunk.val:sub(2)
							end
						else
							chunk.val = "\t"..chunk.val
						end
					end
				end
			end

			self:Invalidate()
		end
	else
		if back and self.text:sub(sub_pos-1,sub_pos-1) == "\t" then
			self:Backspace()
		else
			self:InsertString("\t")
		end
	end

	self:InvalidateEditedText()
end

function META:Enter()
	self:DeleteSelection(true)

	local x = 0
	local y = self.caret_pos.y

	local cur_space = utf8.sub(self.lines[y],1,self.caret_pos.x):match("^(%s*)") or ""
	x = x+#cur_space

	if x == 0 and #self.lines == 1 then
		cur_space = " "..cur_space
	end

	self:InsertString("\n"..cur_space,true)
	self:InvalidateEditedText()

	self.real_x = x

	self:SetCaretPos(x,y+1,true)
end

do -- caret
	function META:SetCaretPos(x,y,later)
		if later then
			self.caret_later_pos = {x,y}
		else
			self.caret_pos = self:CaretFromPos(x,y)
		end
	end

	function META:GetCaretSubPos()
		local caret = self.caret_pos
		return self:GetSubPosFromPos(caret.x,caret.y)
	end

	function META:CaretFromPixels(x,y)

		if self.current_x then
			x = x-self.current_x
			y = y-self.current_y
		end

		local CHAR
		local POS

		for i,char in ipairs(self.chars) do
			if x > char.data.x and y > char.data.y and x < char.data.right and y < char.data.top then
				POS  = i
				CHAR = char
				break
			end
		end
		
		if not CHAR then
			local line = {}
			for i,char in ipairs(self.chars) do
				if y > char.data.y and y < char.data.top+1 then
					table.insert(line,{i,char})
				end
			end

			if #line == 0 then
				for i,char in ipairs(self.chars) do
					if char.chunk.line == #self.lines then
						if y > char.data.y then
							table.insert(line,{i,char})
						end
					end
				end
			end

			if #line > 0 and x > line[#line][2].data.right then
				POS,CHAR = unpack(line[#line])
			end

			if not CHAR then
				for i,v in ipairs(line) do
					local i,char = unpack(v)
					if x < char.data.x then
						POS = i-1
						CHAR = self.chars[POS]
						break
					end
				end
			end
		end

		if not CHAR then
			CHAR =  self.chars[#self.chars]
			POS  = #self.chars
		end

		local data = CHAR.data

		return {
			px      = data.x,
			py      = data.y,
			x       = CHAR.x,
			y       = CHAR.y,
			w       = data.w,
			h       = data.h,
			i       = POS,
			char    = CHAR,
			sub_pos = self:GetSubPosFromPos(CHAR.x,CHAR.y),
		}
	end

	function META:CaretFromPos(x,y)
		x,y = x or 0,y or 0

		y = math.min(math.max(y,1),#self.lines)
		x = math.min(math.max(x,0),self.lines[y] and utf8.length(self.lines[y]) or 0)

		local CHAR
		local POS

		for i,char in ipairs(self.chars) do
			if char.y == y and char.x == x then
				CHAR = char
				POS  = i
				break
			end
		end

		if not CHAR then
			if x == utf8.length(self.lines[#self.lines]) then
				POS  = #self.chars
				CHAR =  self.chars[i]
			end
		end

		if not CHAR then
			if y <= 1 then
				if x <= 0 then
					CHAR = self.chars[1]
					POS = 1
				else
					CHAR = self.chars[x+1]
					POS = x+1
				end
			elseif y >= #self.lines then
				local i = #self.chars-utf8.length(self.lines[#self.lines])+x+1
				CHAR = self.chars[i]
				POS  = i
			end
		end

		if not CHAR then
			CHAR = self.chars[#self.chars]
		end

		local data = CHAR.data

		return {
			px      = data.x,
			py      = data.y,
			x       = CHAR.x,
			y       = CHAR.y,
			h       = data.h,
			w       = data.w,
			i       = POS,
			char    = CHAR,
			sub_pos = self:GetSubPosFromPos(CHAR.x,CHAR.y),
		}
	end

	function META:AdvanceCaret(X,Y)
		if self.ControlDown then
			if X < 0 then
				self:SetCaretPos(self:GetNextCharacterClassPos(-1))
			elseif X > 0 then
				self:SetCaretPos(self:GetNextCharacterClassPos(1))
			end
		end

		local line = self.lines[self.caret_pos.y]
		local x,y  = self.caret_pos.x or 0,self.caret_pos.y or 0

		if Y ~= 0 then
			x = self.real_x
			y = y+Y
		end

		if X ~= math.huge and X ~= -math.huge then
			x = x+X

			if Y == 0 then
				self.real_x = x
			end
			
			if X > 0 and x > utf8.length(line) and #self.lines > 1 then
				x,y = 0,y+1

				if self.ControlDown then
					local line = self.lines[self.caret_pos.y+1] or ""
					x = (line:find("%s-%S",0) or 1)-1
				end
			elseif X < 0 and x < 0 and y > 0 and self.lines[self.caret_pos.y-1] then
				x = utf8.length(self.lines[self.caret_pos.y-1])
				y = y-1
			end
		else
			if X == math.huge then
				x = utf8.length(line)
			elseif X == -math.huge then
				local pos = #(line:match("^(%s*)") or "")
				
				if x == pos then
					pos = 0
				end
				
				x = pos
			end
		end

		if x ~= self.caret_pos.x or y ~= self.caret_pos.y then
			if x < self.caret_pos.x then
				self.suppress_end_char = true
			end

			self:SetCaretPos(x, y)
			
			self.suppress_end_char = false
		end

		self.blink_offset = EXT.GetTime()+0.25
	end
end

do
	function META:SelectStart(x,y)
		self.select_start = self:CaretFromPos(x,y)
	end

	function META:SelectStop(x,y)
		self.select_stop = self:CaretFromPos(x,y)
	end

	function META:GetSelectStart()
		if self.select_start and self.select_stop then
			if self.select_start.i == self.select_stop.i then return end
			if self.select_start.i <  self.select_stop.i then
				return self.select_start
			else
				return self.select_stop
			end
		end
	end

	function META:GetSelectStop()
		if self.select_start and self.select_stop then
			if self.select_start.i == self.select_stop.i then return end
			if self.select_start.i >  self.select_stop.i then
				return self.select_start
			else
				return self.select_stop
			end
		end
	end

	function META:SelectAll()
		self:SetCaretPos(0,0)
		self:SelectStart(0,0)
		self:SelectStop(math.huge,math.huge)
	end

	function META:SelectCurrentWord()
		local x, y = self:GetNextCharacterClassPos(-1,false)
		self:SelectStart(x-1,y)

		local x, y = self:GetNextCharacterClassPos(1,false)
		self:SelectStop(x+1,y)
	end

	function META:SelectCurrentLine()
		self:SelectStart(0,self.caret_pos.y)
		self:SelectStop(math.huge,self.caret_pos.y)
	end

	function META:Unselect()
		self.select_start    = nil
		self.select_stop     = nil
		self.caret_shift_pos = nil
	end

	function META:GetText(tags)
		local start,stop = self:GetSelectStart(),self:GetSelectStop()
		local caret      = self.caret_pos

		self:SelectAll()
		local str = self:GetSelection(tags)

		if start and stop then
			self:SelectStart(start.x,start.y)
			self:SelectStop(stop.x,stop.y)
		else
			self:Unselect()
		end

		self:SetCaretPos(caret.x,caret.y)

		return str
	end

	function META:SetText(str,tags)
		self:Clear()
		self:AddString(str,tags)
		self:Invalidate()
	end

	function META:GetSelection(tags)
		local out = {}

		local START = self:GetSelectStart()
		local STOP  = self:GetSelectStop()

		if START and STOP then
			if not tags then
				return utf8.sub(self.text,START.sub_pos,STOP.sub_pos-1)
			else
				local last_chunk
				local last_font
				local last_color

				for i=START.i,STOP.i do
					local char  = self.chars[i]
					local chunk = char.chunk
					
					if chunk.font and last_font ~= chunk.font then
						table.insert(out,("<font=%s>"):format(chunk.font))
						last_font = chunk.font
					end

					if chunk.color and last_color ~= chunk.color then
						table.insert(out,("<color=%s,%s,%s,%s>"):format(
							math.round(chunk.color.r,2),
							math.round(chunk.color.g,2),
							math.round(chunk.color.b,2),
							math.round(chunk.color.a,2)
						))
						
						last_color = chunk.color
					end

					table.insert(out,char.str)

					if chunk.type == "custom" then
						if chunk.val.type == "texture" then
							table.insert(out,("<texture=%s>"):format(chunk.val.args[1]))
						end
					end
				end
			end
		end

		return table.concat(out,"")
	end

	function META:DeleteSelection(skip_move)
		local start = self:GetSelectStart()
		local stop = self:GetSelectStop()

		if start then
			if not skip_move then
				self:SetCaretPos(start.x,start.y)
			end

			self.text = utf8.sub(self.text,1,start.sub_pos-1)..utf8.sub(self.text,stop.sub_pos)

			self:Unselect()

			do
				local need_fix = false
				for i = start.char.chunk.i+1, stop.char.chunk.i-1 do
					if not self.chunks[i].internal then
						self.chunks[i] = nil
						need_fix = true
					end
				end

				local start_chunk = start.char.chunk
				local stop_chunk  = stop.char.chunk

				if start_chunk.type == "string" then
					if stop_chunk == start_chunk then
						start_chunk.val = utf8.sub(start_chunk.val,1,start.char.data.i-1)..utf8.sub(start_chunk.val,stop.char.data.i)
					else
						start_chunk.val = utf8.sub(start_chunk.val,1,start.char.data.i-1)
					end
				elseif not self.chunks[start_chunk.i].internal then
					self.chunks[start_chunk.i] = nil
					need_fix = true
				end

				if stop_chunk ~= start_chunk then
					if stop_chunk.type == "string" then
						local sub_pos  = stop.char.data.i
						stop_chunk.val = utf8.sub(stop_chunk.val,sub_pos)
					elseif stop_chunk.type ~= "newline" and not stop_chunk.internal then
						self.chunks[stop_chunk.i] = nil
						need_fix = true
					end
				end

				if need_fix then
					EXT.FixIndices(self.chunks)
				end

				self:Invalidate()
			end

			self:InvalidateEditedText()

			return true
		end
		return false
	end

end

do
	function META:Copy(tags)
		return self:GetSelection(tags)
	end

	function META:Cut()
		local str = self:GetSelection()
		self:DeleteSelection()
		return str
	end

	function META:Paste(str)
		str = str:gsub("\r", "")
		
		print(str)

		self:DeleteSelection()

		if #str > 0 then
			self:InsertString(str,(str:find("\n")))
			self:InvalidateEditedText()

			if str:find("\n") then
				self:SetCaretPos(math.huge,self.caret_pos.y+EXT.CountChar(str,"\n"),true)
			end
		end
	end
end

do
	function META:OnCharInput(char)
		self:InsertString(char)
	end

	local is_caret_move = {
		up      = true,
		down    = true,
		left    = true,
		right   = true,
		home    = true,
		["end"] = true,
	}

	function META:OnKeyInput(key,press)
		if not self.Editable or #self.chunks == 0 then return end
		if not self.caret_pos then return end
		
		do
			local x,y = 0,0

			if     key == "up"   and self.Multiline then
				y = -1
			elseif key == "down" and self.Multiline then
				y = 1
			elseif key == "left"  then
				x = -1
			elseif key == "right" then
				x = 1
			elseif key == "home"  then
				x = -math.huge
			elseif key == "end"   then
				x = math.huge
			elseif key == "page_up"   and self.Multiline then
				y = -10
			elseif key == "page_down" and self.Multiline then
				y = 10
			end

			self:AdvanceCaret(x,y)
		end

		if is_caret_move[key] then
			if not self.ShiftDown then
				self:Unselect()
			end
		end

		if key == "tab" then
			self:Indent(self.ShiftDown)
		elseif key == "enter" and self.Multiline then
			self:Enter()
		end

		if self.ControlDown then
			if     key == "c" then
				EXT.SetClipboard(self:Copy())
			elseif key == "x" then
				EXT.SetClipboard(self:Cut())
			elseif key == "v" then
				self:Paste(EXT.GetClipboard())
			elseif key == "a" then
				self:SelectAll()
			elseif key == "t" then
				local str = self:GetSelection()
				self:DeleteSelection()

				for i,chunk in pairs(self:ParseTags(str)) do
					table.insert(self.chunks,self.caret_pos.char.chunk.i+i-1,chunk)
				end

				self:Invalidate()
			end
		end

		if key == "backspace" then
			self:Backspace()
		elseif key == "delete" then
			self:Delete()
		end

		do
			if key ~= "tab" then
				if self.ShiftDown then
					if self.caret_shift_pos then
						self:SelectStart(self.caret_shift_pos.x,self.caret_shift_pos.y)
						self:SelectStop(self.caret_pos.x,self.caret_pos.y)
					end
				elseif is_caret_move[key] then
					self:Unselect()
				end
			end
		end
	end

	function META:OnMouseInput(button,press,x,y)
		if #self.chunks == 0 then return end
		
		local chunk = self:CaretFromPixels(x,y).char.chunk
		
		if chunk.type == "string" and chunk.chunks_inbetween then
			chunk = chunk.chunks_inbetween[1]
		end
		
		if
			chunk.type == "custom" and
			call_tag_func(self,chunk,"mouse",button,press,x,y) == false
		then
			return
		end
		
		if button == "button_1" then
			if press then
				if self.last_click and self.last_click > os.clock() then
					self.times_clicked = (self.times_clicked or 1)+1
				else
					self.times_clicked = 1
				end
				
				if self.times_clicked == 2 then
					self.caret_pos = self:CaretFromPixels(x,y)
					
					if self.caret_pos and self.caret_pos.char then
						self.real_x = self.caret_pos.x
					end
					
					self:SelectCurrentWord()
				elseif self.times_clicked == 3 then
					self:SelectCurrentLine()
				end
				
				self.last_click = os.clock()+0.2
				if self.times_clicked > 1 then return end
			end
			
			if press then
				self.select_start = self:CaretFromPixels(x,y)
				self.select_stop = nil
				self.mouse_selecting = true
				
				self.caret_pos = self:CaretFromPixels(x,y)
				
				if self.caret_pos and self.caret_pos.char then
					self.real_x = self.caret_pos.x
				end
			else
				if not self.Editable then
					EXT.SetClipboard(self:Copy(true))
					self:Unselect()
				end
				
				self.mouse_selecting = false
			end
		end
	end
end

do
	function META:Draw(x,y,w,h,no_translation)
		if gmod then
			EXT.CreateMatrix(true)
			if not no_translation then
				EXT.TranslateMatrix(x,y)
			end
			EXT.PushMatrix()
		end

		if self.need_layout then
			self:Invalidate()
			self.need_layout = false
		end

		if #self.chunks == 0 then return end
		
		if self.move_caret_right then
			self.move_caret_right = false
			self:OnKeyInput("right",true)
		end

		if self.caret_later_pos then
			self:SetCaretPos(unpack(self.caret_later_pos))
			self.caret_later_pos = nil
		end
		
		EXT.SetFont(self.DefaultFont.Name)
		EXT.SetColor(1,1,1,1)

		local remove_these = {}
		local start_remove = false
		local started_tags = {}

		for i,chunk in ipairs(self.chunks) do
			if not chunk.internal then
				if not chunk.x then return end
				if
					chunk.x <  w and chunk.y <  h and
					chunk.x >= 0 and chunk.y >= 0 or
					(chunk.type == "start_fade" or chunk.type == "end_fade") or
					start_remove
				then
					if chunk.type == "start_fade" then
						chunk.alpha = math.min(math.max(chunk.val-os.clock(),0),1)^5
						EXT.SetAlphaMultiplier(chunk.alpha)

						if chunk.alpha <= 0 then
							start_remove = true
						end
					end

					if start_remove then
						remove_these[i] = true
					end

					if     chunk.type == "font"   then
						EXT.SetFont(chunk.val)
					elseif chunk.type == "string" then
						EXT.SetTextPos(chunk.x, chunk.y)
						EXT.DrawText(chunk.val)
					elseif chunk.type == "color"  then
						local c = chunk.val
						
						EXT.SetColor(c.r,c.g,c.b,c.a)
					elseif chunk.type == "tag_stopper" then
						for _,chunks in pairs(started_tags) do
							local fix = false
							
							for key,chunk in pairs(chunks) do
								if next(chunks) then
									call_tag_func(self,chunk,"post_draw",chunk.x,chunk.y)
									chunks[key] = nil
								end
							end
							
							if fix then
								EXT.FixIndices(chunks)
							end
						end
					elseif chunk.type == "custom" then
						if not chunk.init_called and not chunk.val.stop_tag then
							call_tag_func(self,chunk,"init")
							chunk.init_called = true
						end
						
						started_tags[chunk.val.type] = started_tags[chunk.val.type] or {}
						
						if chunk.tag_start_draw then
							if call_tag_func(self,chunk,"pre_draw",chunk.x,chunk.y) then
								if CHATHUD_TAGS[chunk.val.type].post_draw then
									table.insert(started_tags[chunk.val.type],chunk)
								end
							end
							
							if chunk.chunks_inbetween then
								for i,other_chunk in ipairs(chunk.chunks_inbetween) do
									call_tag_func(self,chunk,"pre_draw_chunks",other_chunk)
								end
							end
						end
						
						if chunk.tag_stop_draw then
							if table.remove(started_tags[chunk.val.type]) then
								call_tag_func(self,chunk.start_chunk,"post_draw",chunk.start_chunk.x,chunk.start_chunk.y)
							end
						end
					end
					
					if chunk.tag_stop_draw then
						if table.remove(started_tags[chunk.start_chunk.val.type]) then
							call_tag_func(self,chunk.start_chunk,"post_draw",chunk.start_chunk.x,chunk.start_chunk.y)
						end
						
						for i,other_chunk in ipairs(chunk.chunks_inbetween) do
							call_tag_func(self,chunk.start_chunk,"post_draw_chunks",other_chunk)
						end
					end
					
					if chunk.type == "end_fade" then
						EXT.SetAlphaMultiplier(1)
						start_remove = false
					end
				end
			end
		end

		for _,chunks in pairs(started_tags) do
			for _,chunk in pairs(chunks) do
				call_tag_func(self,chunk,"post_draw",chunk.x,chunk.y)
			end
		end

		if next(remove_these) then
			for k,v in pairs(remove_these) do
				self.chunks[k] = nil
			end

			EXT.FixIndices(self.chunks)

			self:Invalidate()
		end

		self.current_x      = x
		self.current_y      = y
		self.current_width  = w
		self.current_height = h

		self:DrawSelection()

		if gmod then
			EXT.PopMatrix()
		end
	end

	function META:DrawSelection()
		if self.mouse_selecting then
			local x,y = EXT.GetMousePos()
			local caret = self:CaretFromPixels(x,y,true)

			if caret then
				self.select_stop = caret
			end
		end

		if self.ShiftDown then
			if not self.caret_shift_pos then
				self.caret_shift_pos = self:CaretFromPos(self.caret_pos.x,self.caret_pos.y)
			end
		else
			self.caret_shift_pos = nil
		end

		local START = self:GetSelectStart()
		local END = self:GetSelectStop()

		if START and END then
			EXT.SetWhiteTexture()
			EXT.SetColor(1,1,1,0.5)

			for i=START.i,END.i-1 do
				local char = self.chars[i]
				if char then
					local data = char.data
					EXT.DrawRect(data.x,data.y,data.w,data.h)
				end
			end

			if self.Editable then
				self:DrawLineHighlight(self.select_stop.y)
			end
		elseif self.Editable then
			self:DrawCaret()
			self:DrawLineHighlight(self.caret_pos.char.y)
		end
	end

	function META:DrawLineHighlight(y)
		do return end
		local start_chunk = self:CaretFromPos(0,y).char.chunk
		EXT.SetColor(1,1,1,0.1)
		EXT.DrawRect(start_chunk.x,start_chunk.y,self.width,start_chunk.line_height)
	end

	function META:DrawCaret()
		if self.caret_pos then
			local x = self.caret_pos.px
			local y = self.caret_pos.py
			local h = self.caret_pos.h

			if self.caret_pos.char.chunk.internal then
				local chunk = self.chunks[self.caret_pos.char.chunk.i-1]
				if chunk then
					x = chunk.right
					y = chunk.y
					h = chunk.h
				else
					x = 0
					y = 0
					h = self.caret_pos.char.chunk.real_h
				end
			end

			EXT.SetWhiteTexture()
			self.blink_offset = self.blink_offset or 0
			EXT.SetColor(1,1,1,(EXT.GetTime()-self.blink_offset)%0.5 > 0.25 and 1 or 0)
			EXT.DrawRect(x,y,1,h)
		end
	end
end

do
	function META:Test()
		self:AddString("Hello markup test!\n\n有一些中國\nそして、いくつかの日本の\nكيف حول بعض عربية")
		self:AddString([[
markup todo:
	caret real_x should prioritise pixel width
	y axis caret movement when the text is being wrapped
	divide this up in cells (new object?)
	proper tag stack
	the ability to edit (remove and copy) custom tags that have a size (like textures)
	alignment tags
		]])

		local small_font = "markup_small"
		EXT.CreateFont(small_font,{size=8,read_speed=100})
		
		self:AddFont(small_font)
		self:AddString("\nhere's some text in chinese:\n我寫了這個在谷歌翻譯，所以我可以測試我的標記語言使用Unicode正確。它似乎做工精細！\n")
		self:AddString("some normal string again\n")
		self:AddString("and another one\n")

		self:AddFont("markup_default")
		self:AddString("back to normal!\n\n")

		local small_font = "markup_small4"
		EXT.CreateFont(small_font,{size=14,read_speed=100,monospace=true})

		self:AddFont(small_font)
		self:AddString("monospace\n")
		self:AddString("░█░█░█▀█░█▀█░█▀█░█░█░\n░█▀█░█▀█░█▀▀░█▀▀░▀█▀░\n░▀░▀░▀░▀░▀░░░▀░░░░▀░░\n")
		self:AddString("it's kinda like fullwidth\n")
		self:AddFont("markup_default")

		do
			local icons = file.Find("materials/icon16/*", "GAME")
			local tags = ""
			for i = 1, 32 do
				local path = table.Random(icons)
				tags = tags..("<texture=icon16/%s>%s"):format(path,i%16 == 0 and "\n" or "")
			end

			self:AddString(tags,true)
		end

		self:AddString([[<font=markup_default><color=0.5,0.62,0.75,1>if<color=1,1,1,1> CLIENT<color=0.5,0.62,0.75,1> then
	if<color=1,1,1,1> window<color=0.5,0.62,0.75,1> and<color=0.75,0.75,0.62,1> #<color=1,1,1,1>window<color=0.75,0.75,0.62,1>.<color=1,1,1,1>GetSize<color=0.75,0.75,0.62,1>() ><color=0.5,0.75,0.5,1> 5<color=0.5,0.62,0.75,1> then<color=1,1,1,1>
		timer<color=0.75,0.75,0.62,1>.<color=1,1,1,1>Delay<color=0.75,0.75,0.62,1>(<color=0.5,0.75,0.5,1>0<color=0.75,0.75,0.62,1>,<color=0.5,0.62,0.75,1> function<color=0.75,0.75,0.62,1>()
<color=1,1,1,1>			include<color=0.75,0.75,0.62,1>(<color=0.75,0.5,0.5,1>"tests/markup.lua"<color=0.75,0.75,0.62,1>)
<color=0.5,0.62,0.75,1>		end<color=0.75,0.75,0.62,1>)
<color=0.5,0.62,0.75,1>	end
end
	]],true)

		local big_font = "markup_test_big"
		EXT.CreateFont(big_font,{font="arial",size=30,read_speed=100})

		self:AddFont(big_font)
		self:AddColor(Color(0,255,0,255))
		self:AddString("This font is huge and green for some reason!\n")
		self:AddColor(Color(255, 255, 255, 255))
		self:AddFont("markup_default")

		local big_font = "markup_big2"
		EXT.CreateFont(big_font,{font="verdana",size=20,read_speed=100})

		self:AddFont(big_font)
		self:AddColor(Color(255,0,255,255))
		self:AddString("This one is slightly smaller bug with a different font\n")
		self:AddColor(Color(255,255,255,255))
		self:AddFont("markup_default")
		
		self:AddString("Hey look it's gordon freeman!\n")
		self:AddString("<click>http://www.google.com</click>\n",true)
		self:AddString("did you forget your <mark>eggs</mark>?\n",true)
		self:AddString("no but that's <wrong>wierd</wrong>\n",true)
		self:AddString("what's so <rotate=-3>wierd</rotate> about that?\n",true)
		self:AddString("<hsv=[t()+input.rand/10],[(t()+input.rand)/100]>",true)
		self:AddString("<rotate=1>i'm not sure it seems to be</rotate><rotate=-1>some kind of</rotate><physics=0,0>interference</physics>\n",true)
		self:AddString("<scale=[((t()/10)%5^5)+1],1>you don't say</scale>\n",true)

		self:AddString("smileys?")
		self:AddString("\n")
		self:AddString("<rotate=90>:D</rotate>",true)
		self:AddString("<rotate=90>:)</rotate>",true)
		self:AddString("<rotate=90>:(</rotate>",true)
		self:AddString("<rotate=90>:P</rotate>",true)
		self:AddString("<rotate=90>:O</rotate>",true)
		self:AddString("<rotate=90>:]</rotate>",true)
		self:AddString("<rotate=90></rotate>"  ,true)
		self:AddString("\n")
		self:AddString("maybe..\n\n")

		local big_font = "markup_big3"
		EXT.CreateFont(big_font,{font="looney",size=50,read_speed=100})
		self:AddFont(big_font)
		local str = "That's all folks!"

		self:AddFont("markup_default")
		self:AddString("\n")
		self:AddString([[
© 2012, Author
Self publishing
(Possibly email address or contact data)]])
	end
end

if gmod then
	function MarkupTest()
		if markup_frame and markup_frame:IsValid() then
			markup_frame:Remove()
		end

		local frame = vgui.Create("DFrame")
		local scroll = vgui.Create("DScrollPanel",frame)
		local markup = vgui.Create("Markup",scroll)
		
		scroll:Dock(FILL)
		markup:Test()

		function frame.PerformLayout(...)
			markup:SizeToContents(scroll:GetWide())
			DFrame.PerformLayout(...)
		end

		frame:SetSize(1000,1000)
		frame:SetSizable(true)

		markup_frame = frame
	end

	local PANEL = {}

	for k,v in pairs(META) do
		if type(v) == "function" then
			PANEL[k] = function(s, ...)
				return s.markup[k](s.markup,...)
			end
		end
	end

	function PANEL:Init()
		self.markup = Markup()
		self:SetupTextEntryHack()
		self.markup.OnTextChanged = function(m,str)
			if self.OnTextChanged then
				self:OnTextChanged(str)
			end
		end
	end

	function PANEL:SizeToContents(w)
		self.markup:Invalidate()
		self:SetSize(w or self.markup.width,self.markup.height)
	end

	local vec = Vector(0,0,0)

	function PANEL:Paint(w, h)
		local markup = self.markup

		markup:SetShiftDown(  input.IsKeyDown(KEY_LSHIFT  ) or input.IsKeyDown(KEY_RSHIFT  ))
		markup:SetControlDown(input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL))
		
		local x,y = self:LocalToScreen(0,0)

		markup:Draw(x,y,w,self.accurate_height or h,true)
	end

	function PANEL:PerformLayout()
		self.markup:SetMaxWidth(self:GetWide())

		local parent = self:GetParent() or NULL
		local h = parent:GetTall()

		while parent:IsValid() do
			if parent:GetTall() < h then
				h = parent:GetTall()
			end
			parent = parent:GetParent() or NULL
		end

		self.accurate_height = h+100
	end

	do
		local translate = {
			[MOUSE_LEFT]  = "button_1",
			[MOUSE_RIGHT] = "button_2",
		}

		function PANEL:OnMousePressed(button)
			self.markup:OnMouseInput(translate[button],true,gui.MousePos())

			local pnl = self.text_entry_hack
			if pnl:IsValid() then
				pnl:MakePopup()
				pnl:RequestFocus()
			end
		end

		function PANEL:OnMouseReleased(button)
			self.markup:OnMouseInput(translate[button],false,gui.MousePos())
		end

	end

	do
		local translate = {
			[KEY_BACKSPACE] = "backspace",
			[KEY_TAB]       = "tab",
			[KEY_DELETE]    = "delete",
			[KEY_HOME]      = "home",
			[KEY_END]       = "end",
			[KEY_TAB]       = "tab",
			[KEY_ENTER]     = "enter",
			[KEY_C]         = "c",
			[KEY_X]         = "x",
			[KEY_V]         = "v",
			[KEY_A]         = "a",
			[KEY_T]         = "t",
			[KEY_UP]        = "up",
			[KEY_DOWN]      = "down",
			[KEY_LEFT]      = "left",
			[KEY_RIGHT]     = "right",
			[KEY_PAGEUP]    = "page_up",
			[KEY_PAGEDOWN]  = "page_down",
			[KEY_LSHIFT]    = "left_shift",
			[KEY_RSHIFT]    = "right_shift",
			[KEY_RCONTROL]  = "right_control",
			[KEY_LCONTROL]  = "left_control"
		}

		function PANEL:OnKeyInput(key)
			if self.OnKey and self:OnKey(key) == false then return end
			
			key = translate[key]

			if key then
				self.markup:OnKeyInput(key)
			end
		end

		function PANEL:OnCharInput(char)
			if self.OnChar and self:OnChar(char) == false then return end

			self.markup:OnCharInput(char)
		end
	end

	function PANEL:SetupTextEntryHack()
		if IsValid(self.text_entry_hack) then
			self.text_entry_hack:Remove()
		end

		local pnl = vgui.Create("DTextEntry",self)

		pnl:MakePopup()
		pnl:RequestFocus()
		pnl:SetSize(0,0)
		pnl:SetPos(self:LocalToScreen())
		pnl:SetHistoryEnabled(false)
		pnl:SetAllowNonAsciiCharacters(true)

		pnl.OnTextChanged = function(pnl)
			local str = pnl:GetValue()
			if str ~= "" then
				self:OnCharInput(str)
				pnl:SetText("")
			end
		end

		pnl.OnKeyCodeTyped = function(pnl,key)
			self:OnKeyInput(key)
		end

		self.text_entry_hack = pnl
	end

	vgui.Register("Markup", PANEL,"Panel")
end