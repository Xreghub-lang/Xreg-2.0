loadstring([==[
--// Xreg Hub | Defusal (CN Entertainment) | v2
--// Key: 14cf5b20-87f1-457a-8385-c88c8fda3f4d | Insert=UI | RMB=aim | Space/Ctrl=fly altitude

local KEY="14cf5b20-87f1-457a-8385-c88c8fda3f4d"
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local VUser=game:GetService("VirtualUser")
local Camera=workspace.CurrentCamera
local LP=Players.LocalPlayer
local floor,clamp=math.floor,math.clamp

local CFG={
    ESP_ENABLED=true,ESP_BOX=true,ESP_NAME=true,ESP_DISTANCE=true,
    ESP_HEALTH_BAR=true,ESP_TRACER=false,ESP_HEAD_DOT=true,ESP_SKELETON=false,
    TEAM_COLORS=true,BOX_THICKNESS=1.5,TEXT_SIZE=13,
    BOMB_MODEL_NAME="Bomb", -- volatile: verify in workspace tree
    AIM_ENABLED=false,AIM_SMOOTH=0.15,AIM_FOV=150,AIM_SHOW_FOV=true,
    AIM_BONE="Head",SILENT_AIM=false,AUTO_FIRE=false,
    NO_MUZZLE=false,FOV_VALUE=70,FULLBRIGHT=false,NO_FOG=false,
    CROSSHAIR=false,CROSSHAIR_STYLE="Cross",
    WALKSPEED=16,JUMP_POWER=50,INF_JUMP=false,NOCLIP=false,
    FLY_ENABLED=false,FLY_SPEED=50,
    ANTI_AFK=false,SPEC_LIST=false,HIT_SOUND=false,
    COLOR_CT=Color3.fromRGB(80,160,255),COLOR_T=Color3.fromRGB(255,80,80),
    COLOR_SELF=Color3.fromRGB(100,255,100),COLOR_BOMB=Color3.fromRGB(255,220,0),
    COLOR_TEXT=Color3.fromRGB(255,255,255),COLOR_SHADOW=Color3.fromRGB(0,0,0),
}

-- ── Drawing ──────────────────────────────────────────────────
local function newLine(t,c) local l=Drawing.new("Line") l.Thickness=t or 1 l.Color=c or Color3.new(1,1,1) l.Transparency=1 l.Visible=false l.ZIndex=5 return l end
local function newText(s,c,ce) local t=Drawing.new("Text") t.Size=s or 13 t.Color=c or Color3.new(1,1,1) t.Outline=true t.Center=ce or false t.Visible=false t.Font=Drawing.Fonts.UI t.ZIndex=6 return t end
local function newQuad(c,t) local ok,q=pcall(function() return Drawing.new("Quad") end) if not ok then return setmetatable({},{__index=function() return function()end end,__newindex=function()end}) end q.Color=c or Color3.new(1,0,0) q.Thickness=t or 1.5 q.Filled=false q.Visible=false q.ZIndex=5 return q end
local function newRect(f,c,tr) local r=Drawing.new("Square") r.Filled=f~=false r.Color=c or Color3.new(0,0,0) r.Transparency=tr or 0.5 r.Visible=false r.ZIndex=4 return r end
local function newCircle(rad,c,t,f) local ci=Drawing.new("Circle") ci.Radius=rad or 50 ci.Color=c or Color3.new(1,1,1) ci.Thickness=t or 1 ci.Filled=f or false ci.Visible=false ci.ZIndex=7 return ci end

-- ── Utils ─────────────────────────────────────────────────────
local function w2s(pos) local sp,on=Camera:WorldToViewportPoint(pos) return Vector2.new(sp.X,sp.Y),on,sp.Z end
local function getHPColor(f) return Color3.fromRGB(floor(clamp(2*(1-f),0,1)*220),floor(clamp(2*f,0,1)*200),40) end
local function getTeamColor(p)
    if p==LP then return CFG.COLOR_SELF end
    if not CFG.TEAM_COLORS then return CFG.COLOR_T end
    local tm=p.Team
    if tm then local n=tm.Name:lower()
        if n:find("counter") or n:find("ct") or n:find("defend") or n:find("blue") then return CFG.COLOR_CT end
    end
    return CFG.COLOR_T
end
local function getCharBounds(char)
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return nil end
    local tp=hrp.Position+Vector3.new(0,3.5,0) local bp=hrp.Position+Vector3.new(0,-3,0)
    local tsp,ton,tz=w2s(tp) local bsp=w2s(bp)
    if (not ton) or tz<0 then return nil end
    local h=math.abs(tsp.Y-bsp.Y) local hw=h*0.45/2
    return{TL=Vector2.new(tsp.X-hw,tsp.Y),TR=Vector2.new(tsp.X+hw,tsp.Y),
           BR=Vector2.new(bsp.X+hw,bsp.Y),BL=Vector2.new(bsp.X-hw,bsp.Y),
           top=tsp,bot=bsp,cx=tsp.X,h=h,hw=hw,dist=tz}
end
local function findBomb()
    local b=workspace:FindFirstChild(CFG.BOMB_MODEL_NAME,true) if not b then return nil end
    if b:IsA("BasePart") then return b end return b:FindFirstChildOfClass("BasePart")
end

-- ── Skeleton defs ─────────────────────────────────────────────
local SKEL_R15={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local SKEL_R6={{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}
local MAX_SKEL=#SKEL_R15

-- ── Aimbot ────────────────────────────────────────────────────
local function getAimTarget()
    local vp=Camera.ViewportSize
    local center=Vector2.new(vp.X/2,vp.Y/2)
    local best,bestDist=nil,CFG.AIM_FOV
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then continue end
        local bone=char:FindFirstChild(CFG.AIM_BONE) or char:FindFirstChild("HumanoidRootPart")
        if not bone then continue end
        local sp,on,z=w2s(bone.Position)
        if not on or z<0 then continue end
        local d=(sp-center).Magnitude
        if d<bestDist then bestDist=d best=bone end
    end
    return best
end

-- ── ESP pool ──────────────────────────────────────────────────
local ESPPool={}
local function allocESP(p)
    local c=getTeamColor(p) local sk={}
    for i=1,MAX_SKEL do sk[i]=newLine(1,Color3.new(1,1,1)) end
    return{boxOut=newQuad(CFG.COLOR_SHADOW,CFG.BOX_THICKNESS+1.5),box=newQuad(c,CFG.BOX_THICKNESS),
           name=newText(CFG.TEXT_SIZE,CFG.COLOR_TEXT,true),dist=newText(CFG.TEXT_SIZE-1,Color3.fromRGB(180,180,180),true),
           hpBg=newRect(true,Color3.fromRGB(20,20,20),0.5),hpBar=newRect(true,Color3.fromRGB(50,200,80),1),
           tracer=newLine(1,c),headDot=newCircle(4,c,2,false),skel=sk}
end
local function hideESP(o)
    o.boxOut.Visible=false o.box.Visible=false o.name.Visible=false o.dist.Visible=false
    o.hpBg.Visible=false o.hpBar.Visible=false o.tracer.Visible=false o.headDot.Visible=false
    for _,l in ipairs(o.skel) do l.Visible=false end
end
local function freeESP(o)
    o.boxOut:Remove() o.box:Remove() o.name:Remove() o.dist:Remove()
    o.hpBg:Remove() o.hpBar:Remove() o.tracer:Remove() o.headDot:Remove()
    for _,l in ipairs(o.skel) do l:Remove() end
end

-- ── Shared drawing objects ────────────────────────────────────
local BombESP={label=newText(CFG.TEXT_SIZE,CFG.COLOR_BOMB,true),tracer=newLine(1.5,CFG.COLOR_BOMB)}
local fovCircle=newCircle(CFG.AIM_FOV,Color3.fromRGB(255,255,255),1,false)
local CH={
    uO=newLine(2.5,Color3.new(0,0,0)),dO=newLine(2.5,Color3.new(0,0,0)),
    lO=newLine(2.5,Color3.new(0,0,0)),rO=newLine(2.5,Color3.new(0,0,0)),
    u=newLine(1.5,Color3.new(1,1,1)),d=newLine(1.5,Color3.new(1,1,1)),
    l=newLine(1.5,Color3.new(1,1,1)),r=newLine(1.5,Color3.new(1,1,1)),
    dot=newCircle(2,Color3.new(1,1,1),1,true),
    circle=newCircle(8,Color3.new(1,1,1),1,false),
    circleO=newCircle(8,Color3.new(0,0,0),2.5,false),
}
local CH_ALL={CH.u,CH.d,CH.l,CH.r,CH.uO,CH.dO,CH.lO,CH.rO,CH.dot,CH.circle,CH.circleO}
local hitSfx=Instance.new("Sound") hitSfx.SoundId="rbxassetid://7248156132" hitSfx.Volume=0.4 hitSfx.Parent=LP.PlayerGui
local specLabel=newText(12,Color3.fromRGB(200,200,200),false)

-- ── State ─────────────────────────────────────────────────────
local aiming=false local silentOrigCF=nil local jumpConn=nil local muzzleT=0
local origFogEnd,origAmbient,origBrightness,origOutdoorAmbient

-- ── Input ─────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(i,gpe)
    if gpe then return end
    if i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=true end
    if i.UserInputType==Enum.UserInputType.MouseButton1 and CFG.SILENT_AIM and CFG.AIM_ENABLED then
        local tgt=getAimTarget()
        if tgt then silentOrigCF=Camera.CFrame Camera.CFrame=CFrame.new(Camera.CFrame.Position,tgt.Position) end
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=false end
    if i.UserInputType==Enum.UserInputType.MouseButton1 and silentOrigCF then Camera.CFrame=silentOrigCF silentOrigCF=nil end
end)

-- ── Player functions ──────────────────────────────────────────
local function applySpeed()
    local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed=CFG.WALKSPEED hum.JumpPower=CFG.JUMP_POWER end
end
local function enableFly()
    local char=LP.Character if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp or hrp:FindFirstChild("_XFV") then return end
    local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand=true end
    local bv=Instance.new("BodyVelocity") bv.Name="_XFV" bv.Velocity=Vector3.new() bv.MaxForce=Vector3.new(1e5,1e5,1e5) bv.Parent=hrp
    local bg=Instance.new("BodyGyro") bg.Name="_XFG" bg.MaxTorque=Vector3.new(1e5,1e5,1e5) bg.CFrame=hrp.CFrame bg.P=1e4 bg.Parent=hrp
end
local function disableFly()
    local char=LP.Character local hrp=char and char:FindFirstChild("HumanoidRootPart")
    if hrp then local v=hrp:FindFirstChild("_XFV") if v then v:Destroy() end local g=hrp:FindFirstChild("_XFG") if g then g:Destroy() end end
    local hum=char and char:FindFirstChildOfClass("Humanoid") if hum then hum.PlatformStand=false end
end
local function setInfJump(on)
    if jumpConn then jumpConn:Disconnect() jumpConn=nil end
    if on then jumpConn=UIS.JumpRequest:Connect(function()
        local hum=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end) end
end
local function setFullbright(on)
    if on then
        origAmbient=Lighting.Ambient origBrightness=Lighting.Brightness origOutdoorAmbient=Lighting.OutdoorAmbient
        Lighting.Ambient=Color3.fromRGB(255,255,255) Lighting.Brightness=2 Lighting.OutdoorAmbient=Color3.fromRGB(255,255,255)
        for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("ColorCorrectionEffect") or v:IsA("BlurEffect") then v.Enabled=false end end
    else
        if origAmbient then Lighting.Ambient=origAmbient end
        if origBrightness then Lighting.Brightness=origBrightness end
        if origOutdoorAmbient then Lighting.OutdoorAmbient=origOutdoorAmbient end
        for _,v in ipairs(Lighting:GetChildren()) do if v:IsA("ColorCorrectionEffect") or v:IsA("BlurEffect") then v.Enabled=true end end
    end
end
local function setNoFog(on)
    if on then origFogEnd=Lighting.FogEnd Lighting.FogEnd=1e6
    else if origFogEnd then Lighting.FogEnd=origFogEnd end end
end
local function disableMuzzle()
    local char=LP.Character if not char then return end
    for _,obj in ipairs(char:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
            local pn=(obj.Parent and obj.Parent.Name:lower()) or ""
            if pn:find("muzzle") or obj.Name:lower():find("flash") or obj.Name:lower():find("muzzle") then obj.Enabled=false end
        end
    end
end

-- ── Hit sound ─────────────────────────────────────────────────
local function watchHum(hum)
    local last=hum.Health
    hum:GetPropertyChangedSignal("Health"):Connect(function()
        if CFG.HIT_SOUND and hum.Health<last and hum.Health>0 then hitSfx:Play() end
        last=hum.Health
    end)
end
local function watchPlayer(p)
    p.CharacterAdded:Connect(function(char)
        local hum=char:WaitForChild("Humanoid",5) if hum then watchHum(hum) end
    end)
    if p.Character then local hum=p.Character:FindFirstChildOfClass("Humanoid") if hum then watchHum(hum) end end
end
for _,p in ipairs(Players:GetPlayers()) do if p~=LP then watchPlayer(p) end end
Players.PlayerAdded:Connect(function(p) if p~=LP then watchPlayer(p) end end)

-- Anti-AFK
LP.Idled:Connect(function()
    if CFG.ANTI_AFK then pcall(function() VUser:CaptureController() VUser:ClickButton2(Vector2.new()) end) end
end)

-- ════════════════════════════════════════════════════════════
-- RENDER LOOP
-- ════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    local vp=Camera.ViewportSize
    local sb=Vector2.new(vp.X/2,vp.Y-5)
    local sc=Vector2.new(vp.X/2,vp.Y/2)
    local now=tick()

    fovCircle.Position=sc fovCircle.Radius=CFG.AIM_FOV fovCircle.Visible=CFG.AIM_ENABLED and CFG.AIM_SHOW_FOV

    if CFG.AIM_ENABLED and aiming and not CFG.SILENT_AIM then
        local tgt=getAimTarget()
        if tgt then Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,tgt.Position),CFG.AIM_SMOOTH) end
    end
    if CFG.AUTO_FIRE and CFG.AIM_ENABLED and getAimTarget() then pcall(function() mouse1click() end) end
    if CFG.NO_MUZZLE and now-muzzleT>0.1 then muzzleT=now disableMuzzle() end

    if CFG.NOCLIP then
        local char=LP.Character
        if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end

    if CFG.FLY_ENABLED then
        local char=LP.Character local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            if not hrp:FindFirstChild("_XFV") then enableFly() end
            local bv=hrp:FindFirstChild("_XFV") local bg=hrp:FindFirstChild("_XFG")
            if bv and bg then
                local mv=Vector3.new()
                if UIS:IsKeyDown(Enum.KeyCode.W) then mv=mv+Camera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.S) then mv=mv-Camera.CFrame.LookVector end
                if UIS:IsKeyDown(Enum.KeyCode.A) then mv=mv-Camera.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.D) then mv=mv+Camera.CFrame.RightVector end
                if UIS:IsKeyDown(Enum.KeyCode.Space) then mv=mv+Vector3.new(0,1,0) end
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then mv=mv+Vector3.new(0,-1,0) end
                bv.Velocity=mv.Magnitude>0 and mv.Unit*CFG.FLY_SPEED or Vector3.new()
                bg.CFrame=Camera.CFrame
            end
        end
    end

    applySpeed()

    -- Crosshair
    if CFG.CROSSHAIR then
        local gap,len=5,10 local s=CFG.CROSSHAIR_STYLE
        if s=="Cross" then
            CH.uO.From=Vector2.new(sc.X,sc.Y-gap-len) CH.uO.To=Vector2.new(sc.X,sc.Y-gap) CH.uO.Visible=true
            CH.dO.From=Vector2.new(sc.X,sc.Y+gap) CH.dO.To=Vector2.new(sc.X,sc.Y+gap+len) CH.dO.Visible=true
            CH.lO.From=Vector2.new(sc.X-gap-len,sc.Y) CH.lO.To=Vector2.new(sc.X-gap,sc.Y) CH.lO.Visible=true
            CH.rO.From=Vector2.new(sc.X+gap,sc.Y) CH.rO.To=Vector2.new(sc.X+gap+len,sc.Y) CH.rO.Visible=true
            CH.u.From=Vector2.new(sc.X,sc.Y-gap-len) CH.u.To=Vector2.new(sc.X,sc.Y-gap) CH.u.Visible=true
            CH.d.From=Vector2.new(sc.X,sc.Y+gap) CH.d.To=Vector2.new(sc.X,sc.Y+gap+len) CH.d.Visible=true
            CH.l.From=Vector2.new(sc.X-gap-len,sc.Y) CH.l.To=Vector2.new(sc.X-gap,sc.Y) CH.l.Visible=true
            CH.r.From=Vector2.new(sc.X+gap,sc.Y) CH.r.To=Vector2.new(sc.X+gap+len,sc.Y) CH.r.Visible=true
            CH.dot.Visible=false CH.circle.Visible=false CH.circleO.Visible=false
        elseif s=="Dot" then
            CH.dot.Position=sc CH.dot.Visible=true
            for _,v in ipairs({CH.u,CH.d,CH.l,CH.r,CH.uO,CH.dO,CH.lO,CH.rO,CH.circle,CH.circleO}) do v.Visible=false end
        elseif s=="Circle" then
            CH.circle.Position=sc CH.circle.Visible=true CH.circleO.Position=sc CH.circleO.Visible=true
            for _,v in ipairs({CH.u,CH.d,CH.l,CH.r,CH.uO,CH.dO,CH.lO,CH.rO,CH.dot}) do v.Visible=false end
        end
    else for _,v in ipairs(CH_ALL) do v.Visible=false end end

    -- Spec list
    if CFG.SPEC_LIST then
        local dead={}
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=LP then
                local hum=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                if not p.Character or (hum and hum.Health<=0) then table.insert(dead,p.Name) end
            end
        end
        if #dead>0 then specLabel.Text="Spectating:\n"..table.concat(dead,"\n") specLabel.Position=Vector2.new(vp.X-140,90) specLabel.Visible=true
        else specLabel.Visible=false end
    else specLabel.Visible=false end

    -- ESP
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LP then continue end
        if not ESPPool[player] then ESPPool[player]=allocESP(player) end
        local obj=ESPPool[player]
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then hideESP(obj) continue end
        local b=getCharBounds(char)
        if not b or not CFG.ESP_ENABLED then hideESP(obj) continue end
        local color=getTeamColor(player) local hp=clamp(hum.Health/hum.MaxHealth,0,1)
        local pad=Vector2.new(1,1)
        obj.boxOut.PointA=b.TL-pad obj.boxOut.PointB=b.TR+Vector2.new(1,-1) obj.boxOut.PointC=b.BR+pad obj.boxOut.PointD=b.BL+Vector2.new(-1,1) obj.boxOut.Visible=CFG.ESP_BOX
        obj.box.PointA=b.TL obj.box.PointB=b.TR obj.box.PointC=b.BR obj.box.PointD=b.BL obj.box.Color=color obj.box.Visible=CFG.ESP_BOX
        obj.name.Text=player.Name obj.name.Color=color obj.name.Position=Vector2.new(b.cx,b.TL.Y-16) obj.name.Visible=CFG.ESP_NAME
        obj.dist.Text=floor(b.dist).."m" obj.dist.Position=Vector2.new(b.cx,b.BL.Y+2) obj.dist.Visible=CFG.ESP_DISTANCE
        if CFG.ESP_HEALTH_BAR then
            local bx=b.TL.X-6 local bh=b.h local fh=bh*hp
            obj.hpBg.Position=Vector2.new(bx,b.TL.Y) obj.hpBg.Size=Vector2.new(4,bh) obj.hpBg.Visible=true
            obj.hpBar.Position=Vector2.new(bx,b.TL.Y+(bh-fh)) obj.hpBar.Size=Vector2.new(4,fh) obj.hpBar.Color=getHPColor(hp) obj.hpBar.Visible=true
        else obj.hpBg.Visible=false obj.hpBar.Visible=false end
        obj.tracer.From=sb obj.tracer.To=b.bot obj.tracer.Color=color obj.tracer.Visible=CFG.ESP_TRACER
        local head=char:FindFirstChild("Head")
        if CFG.ESP_HEAD_DOT and head then
            local hsp,hon,hz=w2s(head.Position)
            if hon and hz>0 then obj.headDot.Position=hsp obj.headDot.Color=color obj.headDot.Visible=true
            else obj.headDot.Visible=false end
        else obj.headDot.Visible=false end
        if CFG.ESP_SKELETON then
            local boneSet=char:FindFirstChild("UpperTorso") and SKEL_R15 or SKEL_R6 local li=1
            for _,pair in ipairs(boneSet) do
                local a=char:FindFirstChild(pair[1]) local b2=char:FindFirstChild(pair[2]) local ln=obj.skel[li]
                if ln then
                    if a and b2 then
                        local sp1,_,z1=w2s(a.Position) local sp2,_,z2=w2s(b2.Position)
                        if z1>0 and z2>0 then ln.From=sp1 ln.To=sp2 ln.Color=color ln.Visible=true else ln.Visible=false end
                    else ln.Visible=false end li+=1
                end
            end
            for i=li,MAX_SKEL do if obj.skel[i] then obj.skel[i].Visible=false end end
        else for _,ln in ipairs(obj.skel) do ln.Visible=false end end
    end

    for player,obj in pairs(ESPPool) do
        if not Players:FindFirstChild(player.Name) then freeESP(obj) ESPPool[player]=nil end
    end

    local bombPart=findBomb()
    if CFG.ESP_ENABLED and bombPart then
        local sp,on,dist=w2s(bombPart.Position)
        if on and dist>0 then
            BombESP.label.Position=Vector2.new(sp.X,sp.Y-14) BombESP.label.Text=string.format("◆ BOMB  %.0fm",dist) BombESP.label.Visible=true
            BombESP.tracer.From=sb BombESP.tracer.To=sp BombESP.tracer.Visible=true
        else
            BombESP.label.Position=Vector2.new(clamp(sp.X,30,vp.X-30),clamp(sp.Y,30,vp.Y-30))
            BombESP.label.Text=string.format("▶ BOMB  %.0fm",dist or 0) BombESP.label.Visible=true BombESP.tracer.Visible=false
        end
    else BombESP.label.Visible=false BombESP.tracer.Visible=false end
end)

-- ════════════════════════════════════════════════════════════
-- GUI
-- ════════════════════════════════════════════════════════════
local function makeGui()
    local old=LP.PlayerGui:FindFirstChild("XregHub") if old then old:Destroy() end
    local gui=Instance.new("ScreenGui") gui.Name="XregHub" gui.ResetOnSpawn=false
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.Parent=LP.PlayerGui

    -- Key screen
    local kf=Instance.new("Frame") kf.Size=UDim2.new(0,340,0,170) kf.Position=UDim2.new(0.5,-170,0.5,-85)
    kf.BackgroundColor3=Color3.fromRGB(14,14,14) kf.BorderSizePixel=0 kf.Parent=gui
    local ka=Instance.new("Frame") ka.Size=UDim2.new(1,0,0,3) ka.BackgroundColor3=Color3.fromRGB(255,220,60) ka.BorderSizePixel=0 ka.Parent=kf
    local ktb=Instance.new("Frame") ktb.Position=UDim2.new(0,0,0,3) ktb.Size=UDim2.new(1,0,0,34) ktb.BackgroundColor3=Color3.fromRGB(20,20,20) ktb.BorderSizePixel=0 ktb.Parent=kf
    local ktl=Instance.new("TextLabel") ktl.Size=UDim2.new(1,0,1,0) ktl.BackgroundTransparency=1 ktl.Text="Xreg Hub" ktl.TextSize=17 ktl.TextColor3=Color3.fromRGB(255,220,60) ktl.Font=Enum.Font.GothamBold ktl.Parent=ktb
    local ksub=Instance.new("TextLabel") ksub.Position=UDim2.new(0,0,0,44) ksub.Size=UDim2.new(1,0,0,18) ksub.BackgroundTransparency=1 ksub.Text="Enter your key to unlock" ksub.TextSize=12 ksub.TextColor3=Color3.fromRGB(140,140,140) ksub.Font=Enum.Font.Gotham ksub.Parent=kf
    local kb=Instance.new("TextBox") kb.Position=UDim2.new(0,16,0,70) kb.Size=UDim2.new(0,230,0,34) kb.BackgroundColor3=Color3.fromRGB(26,26,26) kb.BorderSizePixel=0 kb.Text="" kb.PlaceholderText="Key here..." kb.TextColor3=Color3.fromRGB(255,255,255) kb.PlaceholderColor3=Color3.fromRGB(80,80,80) kb.Font=Enum.Font.Gotham kb.TextSize=13 kb.ClearTextOnFocus=false kb.Parent=kf
    local ksb=Instance.new("TextButton") ksb.Position=UDim2.new(0,254,0,70) ksb.Size=UDim2.new(0,70,0,34) ksb.BackgroundColor3=Color3.fromRGB(255,220,60) ksb.BorderSizePixel=0 ksb.Text="Enter" ksb.TextSize=13 ksb.TextColor3=Color3.fromRGB(14,14,14) ksb.Font=Enum.Font.GothamBold ksb.Parent=kf
    local kerr=Instance.new("TextLabel") kerr.Position=UDim2.new(0,0,0,112) kerr.Size=UDim2.new(1,0,0,16) kerr.BackgroundTransparency=1 kerr.Text="" kerr.TextSize=12 kerr.TextColor3=Color3.fromRGB(255,80,80) kerr.Font=Enum.Font.Gotham kerr.Parent=kf
    local khint=Instance.new("TextLabel") khint.Position=UDim2.new(0,0,0,136) khint.Size=UDim2.new(1,0,0,14) khint.BackgroundTransparency=1 khint.Text="default key: XREG-2025" khint.TextSize=11 khint.TextColor3=Color3.fromRGB(60,60,60) khint.Font=Enum.Font.Gotham khint.Parent=kf

    -- Main panel
    local mf=Instance.new("Frame") mf.Size=UDim2.new(0,430,0,400) mf.Position=UDim2.new(0.5,-215,0.5,-200)
    mf.BackgroundColor3=Color3.fromRGB(14,14,14) mf.BorderSizePixel=0 mf.Active=true mf.Draggable=true mf.Visible=false mf.Parent=gui
    local ma=Instance.new("Frame") ma.Size=UDim2.new(1,0,0,3) ma.BackgroundColor3=Color3.fromRGB(255,220,60) ma.BorderSizePixel=0 ma.Parent=mf
    local mtb=Instance.new("Frame") mtb.Position=UDim2.new(0,0,0,3) mtb.Size=UDim2.new(1,0,0,34) mtb.BackgroundColor3=Color3.fromRGB(20,20,20) mtb.BorderSizePixel=0 mtb.Parent=mf
    local mtl=Instance.new("TextLabel") mtl.Position=UDim2.new(0,12,0,0) mtl.Size=UDim2.new(1,-80,1,0) mtl.BackgroundTransparency=1 mtl.Text="Xreg Hub" mtl.TextSize=15 mtl.TextColor3=Color3.fromRGB(255,220,60) mtl.Font=Enum.Font.GothamBold mtl.TextXAlignment=Enum.TextXAlignment.Left mtl.Parent=mtb
    local ver=Instance.new("TextLabel") ver.Position=UDim2.new(1,-78,0,0) ver.Size=UDim2.new(0,44,1,0) ver.BackgroundTransparency=1 ver.Text="v2.0" ver.TextSize=10 ver.TextColor3=Color3.fromRGB(60,60,60) ver.Font=Enum.Font.Gotham ver.Parent=mtb
    local mcb=Instance.new("TextButton") mcb.Position=UDim2.new(1,-34,0,0) mcb.Size=UDim2.new(0,34,1,0) mcb.BackgroundTransparency=1 mcb.Text="✕" mcb.TextSize=14 mcb.TextColor3=Color3.fromRGB(180,180,180) mcb.Font=Enum.Font.GothamBold mcb.Parent=mtb
    mcb.MouseButton1Click:Connect(function() mf.Visible=false end)

    local tabBar=Instance.new("Frame") tabBar.Position=UDim2.new(0,0,0,37) tabBar.Size=UDim2.new(1,0,0,28) tabBar.BackgroundColor3=Color3.fromRGB(18,18,18) tabBar.BorderSizePixel=0 tabBar.Parent=mf
    local divLine=Instance.new("Frame") divLine.Position=UDim2.new(0,0,0,65) divLine.Size=UDim2.new(1,0,0,1) divLine.BackgroundColor3=Color3.fromRGB(30,30,30) divLine.BorderSizePixel=0 divLine.Parent=mf
    local ca=Instance.new("Frame") ca.Position=UDim2.new(0,0,0,66) ca.Size=UDim2.new(1,0,1,-66) ca.BackgroundTransparency=1 ca.Parent=mf

    local tabFrames,tabBtns={},{}
    local tabNames={"ESP","Aimbot","Visuals","Player","Misc"}
    local tw=1/#tabNames
    local function setTab(name)
        for n,f in pairs(tabFrames) do f.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            b.BackgroundColor3=n==name and Color3.fromRGB(255,220,60) or Color3.fromRGB(18,18,18)
            b.TextColor3=n==name and Color3.fromRGB(14,14,14) or Color3.fromRGB(160,160,160)
        end
    end
    for i,name in ipairs(tabNames) do
        local tb=Instance.new("TextButton") tb.Position=UDim2.new(tw*(i-1),0,0,0) tb.Size=UDim2.new(tw,0,1,0)
        tb.BackgroundColor3=Color3.fromRGB(18,18,18) tb.BorderSizePixel=0 tb.Text=name tb.TextSize=12
        tb.TextColor3=Color3.fromRGB(160,160,160) tb.Font=Enum.Font.GothamBold tb.Parent=tabBar
        tabBtns[name]=tb tb.MouseButton1Click:Connect(function() setTab(name) end)
        local sf=Instance.new("ScrollingFrame") sf.Size=UDim2.new(1,0,1,0) sf.BackgroundTransparency=1
        sf.BorderSizePixel=0 sf.ScrollBarThickness=3 sf.CanvasSize=UDim2.new(0,0,0,0) sf.Visible=false sf.Parent=ca
        tabFrames[name]=sf
    end

    -- Widget builders
    local function mkToggle(parent,label,y,get,set)
        local row=Instance.new("Frame") row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,28) row.BackgroundTransparency=1 row.Parent=parent
        local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,-54,1,0) lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextSize=13 lbl.TextColor3=Color3.fromRGB(210,210,210) lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=row
        local tog=Instance.new("TextButton") tog.Position=UDim2.new(1,-48,0.5,-12) tog.Size=UDim2.new(0,48,0,24) tog.BorderSizePixel=0 tog.Font=Enum.Font.GothamBold tog.TextSize=11 tog.Parent=row
        local function ref() local v=get() tog.BackgroundColor3=v and Color3.fromRGB(70,190,70) or Color3.fromRGB(48,48,48) tog.TextColor3=v and Color3.fromRGB(14,14,14) or Color3.fromRGB(130,130,130) tog.Text=v and "ON" or "OFF" end
        ref() tog.MouseButton1Click:Connect(function() set(not get()) ref() end) return y+32
    end
    local function mkSlider(parent,label,y,mn,mx,get,set)
        local row=Instance.new("Frame") row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,48) row.BackgroundTransparency=1 row.Parent=parent
        local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0,18) lbl.BackgroundTransparency=1 lbl.Text=label..": "..get() lbl.TextSize=13 lbl.TextColor3=Color3.fromRGB(210,210,210) lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=row
        local trk=Instance.new("Frame") trk.Position=UDim2.new(0,0,0,26) trk.Size=UDim2.new(1,0,0,8) trk.BackgroundColor3=Color3.fromRGB(36,36,36) trk.BorderSizePixel=0 trk.Parent=row
        local fill=Instance.new("Frame") fill.Size=UDim2.new((get()-mn)/(mx-mn),0,1,0) fill.BackgroundColor3=Color3.fromRGB(255,220,60) fill.BorderSizePixel=0 fill.Parent=trk
        local drag=false
        local function setVal(x) local frac=clamp((x-trk.AbsolutePosition.X)/trk.AbsoluteSize.X,0,1) local v=math.round(mn+frac*(mx-mn)) set(v) fill.Size=UDim2.new(frac,0,1,0) lbl.Text=label..": "..v end
        trk.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true setVal(i.Position.X) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
        UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setVal(i.Position.X) end end)
        return y+54
    end
    local function mkSelector(parent,label,y,opts,get,set)
        local row=Instance.new("Frame") row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,52) row.BackgroundTransparency=1 row.Parent=parent
        local lbl=Instance.new("TextLabel") lbl.Size=UDim2.new(1,0,0,18) lbl.BackgroundTransparency=1 lbl.Text=label lbl.TextSize=13 lbl.TextColor3=Color3.fromRGB(210,210,210) lbl.Font=Enum.Font.Gotham lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Parent=row
        local bw=1/#opts local btns={}
        local function refBtns() for k,b in pairs(btns) do b.BackgroundColor3=k==get() and Color3.fromRGB(255,220,60) or Color3.fromRGB(36,36,36) b.TextColor3=k==get() and Color3.fromRGB(14,14,14) or Color3.fromRGB(160,160,160) end end
        for i,opt in ipairs(opts) do
            local b=Instance.new("TextButton") b.Position=UDim2.new(bw*(i-1),2,0,22) b.Size=UDim2.new(bw,-4,0,24)
            b.BorderSizePixel=0 b.Text=opt b.TextSize=12 b.Font=Enum.Font.GothamBold b.Parent=row
            btns[opt]=b b.MouseButton1Click:Connect(function() set(opt) refBtns() end)
        end
        refBtns() return y+58
    end

    -- ESP tab
    do local t=tabFrames["ESP"] local y=8
        y=mkToggle(t,"ESP Enabled",  y,function() return CFG.ESP_ENABLED    end,function(v) CFG.ESP_ENABLED=v    end)
        y=mkToggle(t,"Box ESP",      y,function() return CFG.ESP_BOX        end,function(v) CFG.ESP_BOX=v        end)
        y=mkToggle(t,"Name ESP",     y,function() return CFG.ESP_NAME       end,function(v) CFG.ESP_NAME=v       end)
        y=mkToggle(t,"Distance",     y,function() return CFG.ESP_DISTANCE   end,function(v) CFG.ESP_DISTANCE=v   end)
        y=mkToggle(t,"Health Bar",   y,function() return CFG.ESP_HEALTH_BAR end,function(v) CFG.ESP_HEALTH_BAR=v end)
        y=mkToggle(t,"Head Dot",     y,function() return CFG.ESP_HEAD_DOT   end,function(v) CFG.ESP_HEAD_DOT=v   end)
        y=mkToggle(t,"Skeleton",     y,function() return CFG.ESP_SKELETON   end,function(v) CFG.ESP_SKELETON=v   end)
        y=mkToggle(t,"Tracers",      y,function() return CFG.ESP_TRACER     end,function(v) CFG.ESP_TRACER=v     end)
        y=mkToggle(t,"Team Colors",  y,function() return CFG.TEAM_COLORS    end,function(v) CFG.TEAM_COLORS=v    end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- Aimbot tab
    do local t=tabFrames["Aimbot"] local y=8
        y=mkToggle(t,"Aimbot (RMB)", y,function() return CFG.AIM_ENABLED  end,function(v) CFG.AIM_ENABLED=v  end)
        y=mkToggle(t,"Silent Aim",   y,function() return CFG.SILENT_AIM   end,function(v) CFG.SILENT_AIM=v   end)
        y=mkToggle(t,"Auto Fire",    y,function() return CFG.AUTO_FIRE    end,function(v) CFG.AUTO_FIRE=v    end)
        y=mkToggle(t,"Show FOV",     y,function() return CFG.AIM_SHOW_FOV end,function(v) CFG.AIM_SHOW_FOV=v end)
        y=mkSelector(t,"Bone",y,{"Head","UpperTorso","HRP"},
            function() return CFG.AIM_BONE=="HumanoidRootPart" and "HRP" or CFG.AIM_BONE end,
            function(v) CFG.AIM_BONE=v=="HRP" and "HumanoidRootPart" or v end)
        y=mkSlider(t,"Smoothness",y,1,30,function() return math.round(CFG.AIM_SMOOTH*100) end,function(v) CFG.AIM_SMOOTH=v/100 end)
        y=mkSlider(t,"FOV Radius", y,50,400,function() return CFG.AIM_FOV end,function(v) CFG.AIM_FOV=v fovCircle.Radius=v end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- Visuals tab
    do local t=tabFrames["Visuals"] local y=8
        y=mkToggle(t,"No Muzzle Flash",y,function() return CFG.NO_MUZZLE  end,function(v) CFG.NO_MUZZLE=v  end)
        y=mkToggle(t,"Fullbright",     y,function() return CFG.FULLBRIGHT end,function(v) CFG.FULLBRIGHT=v setFullbright(v) end)
        y=mkToggle(t,"No Fog",         y,function() return CFG.NO_FOG     end,function(v) CFG.NO_FOG=v setNoFog(v) end)
        y=mkToggle(t,"Crosshair",      y,function() return CFG.CROSSHAIR  end,function(v) CFG.CROSSHAIR=v  end)
        y=mkSelector(t,"CH Style",y,{"Cross","Dot","Circle"},function() return CFG.CROSSHAIR_STYLE end,function(v) CFG.CROSSHAIR_STYLE=v end)
        y=mkSlider(t,"Camera FOV",y,50,120,function() return CFG.FOV_VALUE end,function(v) CFG.FOV_VALUE=v Camera.FieldOfView=v end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- Player tab
    do local t=tabFrames["Player"] local y=8
        y=mkToggle(t,"Fly  (WASD+Space/Ctrl)",y,function() return CFG.FLY_ENABLED end,function(v) CFG.FLY_ENABLED=v if v then enableFly() else disableFly() end end)
        y=mkToggle(t,"Infinite Jump",y,function() return CFG.INF_JUMP end,function(v) CFG.INF_JUMP=v setInfJump(v) end)
        y=mkToggle(t,"No Clip",      y,function() return CFG.NOCLIP   end,function(v) CFG.NOCLIP=v   end)
        y=mkSlider(t,"Walk Speed",y,16,100,function() return CFG.WALKSPEED  end,function(v) CFG.WALKSPEED=v  end)
        y=mkSlider(t,"Jump Power",y,50,250,function() return CFG.JUMP_POWER end,function(v) CFG.JUMP_POWER=v end)
        y=mkSlider(t,"Fly Speed", y,10,200,function() return CFG.FLY_SPEED  end,function(v) CFG.FLY_SPEED=v  end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- Misc tab
    do local t=tabFrames["Misc"] local y=8
        y=mkToggle(t,"Anti-AFK",      y,function() return CFG.ANTI_AFK  end,function(v) CFG.ANTI_AFK=v  end)
        y=mkToggle(t,"Spectator List",y,function() return CFG.SPEC_LIST end,function(v) CFG.SPEC_LIST=v end)
        y=mkToggle(t,"Hit Sound",     y,function() return CFG.HIT_SOUND end,function(v) CFG.HIT_SOUND=v end)
        local info=Instance.new("TextLabel") info.Position=UDim2.new(0,10,0,y+8) info.Size=UDim2.new(1,-20,0,90)
        info.BackgroundTransparency=1 info.TextWrapped=true info.TextYAlignment=Enum.TextYAlignment.Top
        info.Text="Insert = toggle panel\nRMB = hold to aim\nSilent Aim = LMB snap-aim\nFly: WASD + Space(up) + LCtrl(down)\nSpec List shows dead players (approx)\nBomb name: volatile — check workspace tree"
        info.TextSize=11 info.TextColor3=Color3.fromRGB(65,65,65) info.Font=Enum.Font.Gotham info.TextXAlignment=Enum.TextXAlignment.Left info.Parent=t
        t.CanvasSize=UDim2.new(0,0,0,y+104)
    end

    setTab("ESP")
    ksb.MouseButton1Click:Connect(function()
        if kb.Text==KEY then kf.Visible=false mf.Visible=true else kerr.Text="Invalid key." kb.Text="" end
    end)
    UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==Enum.KeyCode.Insert then mf.Visible=not mf.Visible end
    end)
end

makeGui()
print("[Xreg Hub v2] loaded | key: 14cf5b20-87f1-457a-8385-c88c8fda3f4d | Insert = toggle")
]==])()
