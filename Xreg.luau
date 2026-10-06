loadstring([==[
--// Xreg Hub v2.0 | Defusal (CN Entertainment)
--// Key: 14cf5b20-87f1-457a-8385-c88c8fda3f4d | Insert=UI | Delete=PANIC | RMB=Aim | F2=Tracers

local KEY = "14cf5b20-87f1-457a-8385-c88c8fda3f4d"

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Lighting   = game:GetService("Lighting")
local Camera     = workspace.CurrentCamera
local LP         = Players.LocalPlayer
local floor, clamp = math.floor, math.clamp

local CFG = {
    -- ESP
    ESP_ENABLED=true, ESP_BOX=true, ESP_NAME=true, ESP_DISTANCE=true,
    ESP_HEALTH_BAR=true, ESP_TRACER=false, ESP_HEAD_DOT=true,
    ESP_SKELETON=false, ESP_CHAMS=false, ESP_RAINBOW=false,
    TEAM_COLORS=true, BOX_THICKNESS=1.5, TEXT_SIZE=13,
    BOMB_MODEL_NAME="Bomb", -- volatile: check workspace tree in-game
    -- Aimbot
    AIM_ENABLED=false, AIM_SMOOTH=15, AIM_FOV=150,
    AIM_SHOW_FOV=true, AIM_BONE="Head",
    AIM_PREDICTION=false, AIM_AUTO_FIRE=false,
    -- Visuals
    NO_MUZZLE=false, FOV_VALUE=70, FULLBRIGHT=false, NO_FOG=false,
    CROSSHAIR=false, CROSSHAIR_SIZE=12, CROSSHAIR_GAP=4,
    -- Player
    SPEED_ENABLED=false, SPEED_VALUE=16,
    JUMP_ENABLED=false,  JUMP_VALUE=50,
    INF_JUMP=false, NOCLIP=false,
    -- Misc
    ANTI_AFK=true, SPEC_LIST=true, FPS_COUNTER=true,
    -- Colors
    COLOR_CT    =Color3.fromRGB( 80,160,255), COLOR_T   =Color3.fromRGB(255, 80, 80),
    COLOR_SELF  =Color3.fromRGB(100,255,100), COLOR_BOMB=Color3.fromRGB(255,220,  0),
    COLOR_TEXT  =Color3.fromRGB(255,255,255), COLOR_SHADOW=Color3.fromRGB(0,0,0),
}

-- Save original lighting
local ORIG = {
    Brightness=Lighting.Brightness, Ambient=Lighting.Ambient,
    OutdoorAmbient=Lighting.OutdoorAmbient, ClockTime=Lighting.ClockTime,
    FogStart=Lighting.FogStart, FogEnd=Lighting.FogEnd,
}

-- ── Drawing helpers ───────────────────────────────────────────
local function newLine(t,c)
    local l=Drawing.new("Line") l.Thickness=t or 1 l.Color=c or Color3.new(1,1,1)
    l.Transparency=1 l.Visible=false l.ZIndex=5 return l
end
local function newText(s,c,ce)
    local t=Drawing.new("Text") t.Size=s or 13 t.Color=c or Color3.new(1,1,1)
    t.Outline=true t.Center=ce or false t.Visible=false t.Font=Drawing.Fonts.UI t.ZIndex=6 return t
end
local function newQuad(c,t)
    local ok,q=pcall(function() return Drawing.new("Quad") end)
    if not ok then return setmetatable({},{__index=function() return function()end end,__newindex=function()end}) end
    q.Color=c or Color3.new(1,0,0) q.Thickness=t or 1.5 q.Filled=false q.Visible=false q.ZIndex=5 return q
end
local function newRect(f,c,tr)
    local r=Drawing.new("Square") r.Filled=f~=false r.Color=c or Color3.new(0,0,0)
    r.Transparency=tr or 0.5 r.Visible=false r.ZIndex=4 return r
end
local function newCircle(r,c,t,filled)
    local ci=Drawing.new("Circle") ci.Radius=r or 4 ci.Color=c or Color3.new(1,1,1)
    ci.Thickness=t or 1 ci.Filled=filled or false ci.Visible=false ci.ZIndex=7 return ci
end

-- ── Utility ───────────────────────────────────────────────────
local function w2s(pos)
    local sp,on=Camera:WorldToViewportPoint(pos) return Vector2.new(sp.X,sp.Y),on,sp.Z
end
local function getHPColor(f)
    return Color3.fromRGB(floor(clamp(2*(1-f),0,1)*220),floor(clamp(2*f,0,1)*200),40)
end
local function getTeamColor(p)
    if p==LP then return CFG.COLOR_SELF end
    if not CFG.TEAM_COLORS then return CFG.COLOR_T end
    local t=p.Team if t then local n=t.Name:lower()
        if n:find("counter") or n:find("ct") or n:find("defend") or n:find("blue") then return CFG.COLOR_CT end
    end
    return CFG.COLOR_T
end
local function getCharBounds(char)
    local hrp=char:FindFirstChild("HumanoidRootPart") if not hrp then return nil end
    local tp=hrp.Position+Vector3.new(0,3.5,0) local bp=hrp.Position+Vector3.new(0,-3,0)
    local tsp,ton,tz=w2s(tp) local bsp=w2s(bp) if (not ton) or tz<0 then return nil end
    local h=math.abs(tsp.Y-bsp.Y) local hw=h*0.45/2
    return{TL=Vector2.new(tsp.X-hw,tsp.Y),TR=Vector2.new(tsp.X+hw,tsp.Y),
           BR=Vector2.new(bsp.X+hw,bsp.Y),BL=Vector2.new(bsp.X-hw,bsp.Y),
           top=tsp,bot=bsp,cx=tsp.X,h=h,hw=hw,dist=tz}
end
local function findBomb()
    local b=workspace:FindFirstChild(CFG.BOMB_MODEL_NAME,true) if not b then return nil end
    if b:IsA("BasePart") then return b end return b:FindFirstChildOfClass("BasePart")
end

-- ── Rainbow ───────────────────────────────────────────────────
local rainbowHue=0
local function rainbow() return Color3.fromHSV(rainbowHue,1,1) end

-- ── Skeleton bone connections ─────────────────────────────────
local R15={{"HumanoidRootPart","LowerTorso"},{"LowerTorso","UpperTorso"},{"UpperTorso","Head"},
           {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
           {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
           {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
           {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"}}
local R6={{"HumanoidRootPart","Torso"},{"Torso","Head"},{"Torso","Left Arm"},
          {"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}}

-- ── ESP Pool ──────────────────────────────────────────────────
local ESPPool={}
local ChamPool={}

local function allocESP(p)
    local c=getTeamColor(p)
    local obj={
        boxOut=newQuad(CFG.COLOR_SHADOW,CFG.BOX_THICKNESS+1.5),
        box=newQuad(c,CFG.BOX_THICKNESS),
        name=newText(CFG.TEXT_SIZE,CFG.COLOR_TEXT,true),
        dist=newText(CFG.TEXT_SIZE-1,Color3.fromRGB(180,180,180),true),
        hpBg=newRect(true,Color3.fromRGB(20,20,20),0.5),
        hpBar=newRect(true,Color3.fromRGB(50,200,80),1),
        tracer=newLine(1,c),
        headDot=newCircle(4,c,1,true),
        skel={},
    }
    for i=1,15 do obj.skel[i]=newLine(1,c) end
    return obj
end
local function hideESP(o)
    for k,v in pairs(o) do
        if k~="skel" and type(v)=="table" and v.Visible~=nil then v.Visible=false end
    end
    for _,l in ipairs(o.skel) do l.Visible=false end
end
local function freeESP(o)
    for k,v in pairs(o) do
        if k~="skel" and type(v)=="table" and v.Remove then v:Remove() end
    end
    for _,l in ipairs(o.skel) do l:Remove() end
end

local function getChams(player)
    if ChamPool[player] then return ChamPool[player] end
    local h=Instance.new("Highlight") h.FillTransparency=0.5 h.OutlineTransparency=0
    h.Enabled=false h.Parent=workspace ChamPool[player]=h return h
end
local function updateChams(player,color)
    local h=getChams(player)
    if CFG.ESP_CHAMS and player.Character then
        h.Adornee=player.Character h.FillColor=color h.OutlineColor=color h.Enabled=true
    else h.Enabled=false end
end

-- Bomb + FOV + Crosshair + HUD objects
local BombESP={label=newText(CFG.TEXT_SIZE,CFG.COLOR_BOMB,true),tracer=newLine(1.5,CFG.COLOR_BOMB)}
local fovCircle=newCircle(CFG.AIM_FOV,Color3.fromRGB(255,255,255),1,false)
local CH={
    t=newLine(1.5,Color3.new(1,1,1)), b=newLine(1.5,Color3.new(1,1,1)),
    l=newLine(1.5,Color3.new(1,1,1)), r=newLine(1.5,Color3.new(1,1,1)),
    d=newCircle(2,Color3.new(1,1,1),1,true),
}
local specLabel=newText(12,Color3.fromRGB(255,180,80),true)
local fpsLabel=newText(12,Color3.fromRGB(100,255,100),false)

-- ── Notifications ─────────────────────────────────────────────
local notifQ={} local notifActive={}
local function pushNotif(msg,color)
    table.insert(notifQ,{msg=msg,color=color or Color3.fromRGB(255,220,60),born=tick()})
end
local function tickNotifs()
    local vp=Camera.ViewportSize local now=tick()
    while #notifQ>0 and #notifActive<5 do
        local n=table.remove(notifQ,1)
        table.insert(notifActive,{
            bg=newRect(true,Color3.fromRGB(20,20,20),0.15),
            tx=newText(12,n.color,false),
            born=n.born, life=4, msg=n.msg
        })
        notifActive[#notifActive].tx.Text="  "..n.msg
    end
    local y=vp.Y-30
    for i=#notifActive,1,-1 do
        local e=notifActive[i] local age=now-e.born
        if age>e.life then e.bg:Remove() e.tx:Remove() table.remove(notifActive,i)
        else
            local a=math.min(1,math.min(age/0.25,(e.life-age)/0.4))
            e.bg.Position=Vector2.new(vp.X-232,y) e.bg.Size=Vector2.new(220,22)
            e.bg.Transparency=a*0.8 e.bg.Visible=true
            e.tx.Position=Vector2.new(vp.X-228,y+4) e.tx.Transparency=a e.tx.Visible=true
            y=y-28
        end
    end
end

-- ── Aimbot ────────────────────────────────────────────────────
local aiming=false local autoFireT=0
UIS.InputBegan:Connect(function(i,gpe) if not gpe and i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=true end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton2 then aiming=false end end)

local function getAimTarget()
    local center=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    local best,bestD=nil,CFG.AIM_FOV
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then continue end
        local bone=char:FindFirstChild(CFG.AIM_BONE) or char:FindFirstChild("HumanoidRootPart")
        if not bone then continue end
        local sp,on,z=w2s(bone.Position) if not on or z<0 then continue end
        local d=(sp-center).Magnitude if d<bestD then bestD=d best=bone end
    end
    return best
end

-- ── Muzzle / Lighting ─────────────────────────────────────────
local muzzleT=0
local function disableMuzzle()
    local char=LP.Character if not char then return end
    for _,o in ipairs(char:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Smoke") or o:IsA("Fire") or o:IsA("Sparkles") then
            local pn=(o.Parent and o.Parent.Name:lower()) or "" local on=o.Name:lower()
            if pn:find("muzzle") or on:find("flash") or on:find("muzzle") or on:find("smoke") then o.Enabled=false end
        end
    end
end
local function enableMuzzle()
    local char=LP.Character if not char then return end
    for _,o in ipairs(char:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Smoke") or o:IsA("Fire") then o.Enabled=true end
    end
end
local function setFullbright(v)
    if v then
        Lighting.Brightness=2 Lighting.ClockTime=14
        Lighting.Ambient=Color3.fromRGB(178,178,178) Lighting.OutdoorAmbient=Color3.fromRGB(178,178,178)
    else
        Lighting.Brightness=ORIG.Brightness Lighting.ClockTime=ORIG.ClockTime
        Lighting.Ambient=ORIG.Ambient Lighting.OutdoorAmbient=ORIG.OutdoorAmbient
    end
end
local function setNoFog(v)
    if v then Lighting.FogStart=0 Lighting.FogEnd=999999
    else Lighting.FogStart=ORIG.FogStart Lighting.FogEnd=ORIG.FogEnd end
end

-- ── Movement features ─────────────────────────────────────────
UIS.JumpRequest:Connect(function()
    if not CFG.INF_JUMP then return end
    local char=LP.Character local hum=char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)
RunService.Stepped:Connect(function()
    if not CFG.NOCLIP then return end
    local char=LP.Character if not char then return end
    for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
end)
RunService.Heartbeat:Connect(function()
    local char=LP.Character local hum=char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if CFG.SPEED_ENABLED then hum.WalkSpeed=CFG.SPEED_VALUE else hum.WalkSpeed=16 end
    if CFG.JUMP_ENABLED  then hum.JumpPower=CFG.JUMP_VALUE  else hum.JumpPower=50  end
end)

-- ── Anti-AFK ──────────────────────────────────────────────────
local afkT=0
RunService.Heartbeat:Connect(function()
    if not CFG.ANTI_AFK then return end
    if tick()-afkT>55 then
        afkT=tick()
        local char=LP.Character local hrp=char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame=hrp.CFrame end
    end
end)

-- ── FPS tracking ──────────────────────────────────────────────
local fpsFrames,fpsLast,fpsCurrent=0,tick(),0
RunService.RenderStepped:Connect(function()
    fpsFrames=fpsFrames+1
    if tick()-fpsLast>=1 then fpsCurrent=fpsFrames fpsFrames=0 fpsLast=tick() end
end)

-- ── Spectator detection ───────────────────────────────────────
local function getSpectators()
    local list={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p==LP then continue end
        local char=p.Character local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then table.insert(list,p.Name) end
    end
    return list
end

-- ── Panic ─────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(i,gpe)
    if gpe then return end
    if i.KeyCode==Enum.KeyCode.Delete then
        for k,v in pairs(CFG) do if type(v)==true then CFG[k]=false end end
        CFG.ESP_ENABLED=false CFG.AIM_ENABLED=false CFG.NO_MUZZLE=false
        CFG.FULLBRIGHT=false CFG.NO_FOG=false CFG.CROSSHAIR=false
        CFG.SPEED_ENABLED=false CFG.JUMP_ENABLED=false CFG.INF_JUMP=false CFG.NOCLIP=false
        setFullbright(false) setNoFog(false) enableMuzzle()
        pushNotif("PANIC — all off",Color3.fromRGB(255,80,80))
    end
    if i.KeyCode==Enum.KeyCode.F2 then
        CFG.ESP_TRACER=not CFG.ESP_TRACER
        pushNotif("Tracers "..(CFG.ESP_TRACER and "ON" or "OFF"))
    end
end)

-- ══════════════════════════════════════════════════════════════
-- GUI
-- ══════════════════════════════════════════════════════════════
local function makeGui()
    local old=LP.PlayerGui:FindFirstChild("XregHub") if old then old:Destroy() end
    local gui=Instance.new("ScreenGui")
    gui.Name="XregHub" gui.ResetOnSpawn=false
    gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.Parent=LP.PlayerGui

    local function corner(p,r) local c=Instance.new("UICorner",p) c.CornerRadius=UDim.new(0,r or 6) end
    local function label(p,txt,sz,col,xa,pos,sz2)
        local l=Instance.new("TextLabel",p) l.BackgroundTransparency=1
        l.Text=txt l.TextSize=sz l.TextColor3=col l.Font=Enum.Font.Gotham
        l.TextXAlignment=xa or Enum.TextXAlignment.Center
        if pos then l.Position=pos end if sz2 then l.Size=sz2 end return l
    end

    -- ── KEY SCREEN ────────────────────────────────────────────
    local kf=Instance.new("Frame",gui)
    kf.Size=UDim2.new(0,340,0,178) kf.Position=UDim2.new(0.5,-170,0.5,-89)
    kf.BackgroundColor3=Color3.fromRGB(14,14,14) kf.BorderSizePixel=0 corner(kf)

    local kAccent=Instance.new("Frame",kf) kAccent.Size=UDim2.new(1,0,0,3)
    kAccent.BackgroundColor3=Color3.fromRGB(255,220,60) kAccent.BorderSizePixel=0

    local kHead=Instance.new("Frame",kf) kHead.Position=UDim2.new(0,0,0,3)
    kHead.Size=UDim2.new(1,0,0,36) kHead.BackgroundColor3=Color3.fromRGB(20,20,20) kHead.BorderSizePixel=0
    label(kHead,"Xreg Hub",17,Color3.fromRGB(255,220,60)):setContext and nil
    local kTitle=Instance.new("TextLabel",kHead) kTitle.Size=UDim2.new(1,0,1,0) kTitle.BackgroundTransparency=1
    kTitle.Text="Xreg Hub" kTitle.TextSize=17 kTitle.Font=Enum.Font.GothamBold
    kTitle.TextColor3=Color3.fromRGB(255,220,60)

    local kSub=Instance.new("TextLabel",kf) kSub.Position=UDim2.new(0,0,0,46)
    kSub.Size=UDim2.new(1,0,0,18) kSub.BackgroundTransparency=1
    kSub.Text="Enter your key to unlock" kSub.TextSize=12
    kSub.TextColor3=Color3.fromRGB(140,140,140) kSub.Font=Enum.Font.Gotham

    local kBox=Instance.new("TextBox",kf) kBox.Position=UDim2.new(0,16,0,72)
    kBox.Size=UDim2.new(0,230,0,36) kBox.BackgroundColor3=Color3.fromRGB(26,26,26)
    kBox.BorderSizePixel=0 kBox.Text="" kBox.PlaceholderText="Enter key..."
    kBox.TextColor3=Color3.fromRGB(255,255,255) kBox.PlaceholderColor3=Color3.fromRGB(70,70,70)
    kBox.Font=Enum.Font.Gotham kBox.TextSize=13 kBox.ClearTextOnFocus=false corner(kBox,4)

    local kBtn=Instance.new("TextButton",kf) kBtn.Position=UDim2.new(0,254,0,72)
    kBtn.Size=UDim2.new(0,70,0,36) kBtn.BackgroundColor3=Color3.fromRGB(255,220,60)
    kBtn.BorderSizePixel=0 kBtn.Text="Unlock" kBtn.TextSize=13
    kBtn.TextColor3=Color3.fromRGB(14,14,14) kBtn.Font=Enum.Font.GothamBold corner(kBtn,4)

    local kErr=Instance.new("TextLabel",kf) kErr.Position=UDim2.new(0,0,0,116)
    kErr.Size=UDim2.new(1,0,0,16) kErr.BackgroundTransparency=1 kErr.Text=""
    kErr.TextSize=12 kErr.TextColor3=Color3.fromRGB(255,80,80) kErr.Font=Enum.Font.Gotham

    local kHint=Instance.new("TextLabel",kf) kHint.Position=UDim2.new(0,0,0,140)
    kHint.Size=UDim2.new(1,0,0,14) kHint.BackgroundTransparency=1
    kHint.Text="default: XREG-2025" kHint.TextSize=11
    kHint.TextColor3=Color3.fromRGB(55,55,55) kHint.Font=Enum.Font.Gotham

    local kCredit=Instance.new("TextLabel",kf) kCredit.Position=UDim2.new(0,0,0,158)
    kCredit.Size=UDim2.new(1,0,0,14) kCredit.BackgroundTransparency=1
    kCredit.Text="Xreg Hub v2.0 — Defusal" kCredit.TextSize=11
    kCredit.TextColor3=Color3.fromRGB(255,220,60) kCredit.Font=Enum.Font.GothamBold

    -- ── MAIN PANEL ────────────────────────────────────────────
    local mf=Instance.new("Frame",gui)
    mf.Size=UDim2.new(0,430,0,370) mf.Position=UDim2.new(0.5,-215,0.5,-185)
    mf.BackgroundColor3=Color3.fromRGB(14,14,14) mf.BorderSizePixel=0
    mf.Active=true mf.Draggable=true mf.Visible=false corner(mf)

    local mAccent=Instance.new("Frame",mf) mAccent.Size=UDim2.new(1,0,0,3)
    mAccent.BackgroundColor3=Color3.fromRGB(255,220,60) mAccent.BorderSizePixel=0

    local mHead=Instance.new("Frame",mf) mHead.Position=UDim2.new(0,0,0,3)
    mHead.Size=UDim2.new(1,0,0,36) mHead.BackgroundColor3=Color3.fromRGB(20,20,20) mHead.BorderSizePixel=0

    local mTitle=Instance.new("TextLabel",mHead) mTitle.Position=UDim2.new(0,12,0,0)
    mTitle.Size=UDim2.new(0,160,1,0) mTitle.BackgroundTransparency=1
    mTitle.Text="Xreg Hub" mTitle.TextSize=15 mTitle.Font=Enum.Font.GothamBold
    mTitle.TextColor3=Color3.fromRGB(255,220,60) mTitle.TextXAlignment=Enum.TextXAlignment.Left

    local mVer=Instance.new("TextLabel",mHead) mVer.Position=UDim2.new(0,175,0,0)
    mVer.Size=UDim2.new(0,50,1,0) mVer.BackgroundTransparency=1
    mVer.Text="v2.0" mVer.TextSize=11 mVer.Font=Enum.Font.Gotham
    mVer.TextColor3=Color3.fromRGB(70,70,70) mVer.TextXAlignment=Enum.TextXAlignment.Left

    local mClose=Instance.new("TextButton",mHead) mClose.Position=UDim2.new(1,-36,0,0)
    mClose.Size=UDim2.new(0,36,1,0) mClose.BackgroundTransparency=1
    mClose.Text="✕" mClose.TextSize=14 mClose.Font=Enum.Font.GothamBold
    mClose.TextColor3=Color3.fromRGB(180,180,180)
    mClose.MouseButton1Click:Connect(function() mf.Visible=false end)

    -- Tab bar
    local tabBar=Instance.new("Frame",mf) tabBar.Position=UDim2.new(0,0,0,39)
    tabBar.Size=UDim2.new(1,0,0,30) tabBar.BackgroundColor3=Color3.fromRGB(18,18,18) tabBar.BorderSizePixel=0

    local tabDiv=Instance.new("Frame",mf) tabDiv.Position=UDim2.new(0,0,0,69)
    tabDiv.Size=UDim2.new(1,0,0,1) tabDiv.BackgroundColor3=Color3.fromRGB(28,28,28) tabDiv.BorderSizePixel=0

    local ca=Instance.new("Frame",mf) ca.Position=UDim2.new(0,0,0,70)
    ca.Size=UDim2.new(1,0,1,-70) ca.BackgroundTransparency=1

    local tabNames={"ESP","Aimbot","Visuals","Player","Misc"}
    local tabFrames,tabBtns={},{}
    local tw=1/#tabNames

    local function setTab(name)
        for n,f in pairs(tabFrames) do f.Visible=(n==name) end
        for n,b in pairs(tabBtns) do
            b.BackgroundColor3=n==name and Color3.fromRGB(255,220,60) or Color3.fromRGB(18,18,18)
            b.TextColor3=n==name and Color3.fromRGB(14,14,14) or Color3.fromRGB(155,155,155)
        end
    end

    for i,name in ipairs(tabNames) do
        local tb=Instance.new("TextButton",tabBar)
        tb.Position=UDim2.new(tw*(i-1),0,0,0) tb.Size=UDim2.new(tw,0,1,0)
        tb.BackgroundColor3=Color3.fromRGB(18,18,18) tb.BorderSizePixel=0
        tb.Text=name tb.TextSize=12 tb.Font=Enum.Font.GothamBold
        tb.TextColor3=Color3.fromRGB(155,155,155)
        tabBtns[name]=tb tb.MouseButton1Click:Connect(function() setTab(name) end)

        local sf=Instance.new("ScrollingFrame",ca)
        sf.Size=UDim2.new(1,0,1,0) sf.BackgroundTransparency=1 sf.BorderSizePixel=0
        sf.ScrollBarThickness=3 sf.CanvasSize=UDim2.new(0,0,0,0) sf.Visible=false
        tabFrames[name]=sf
    end

    -- ── Widget builders ───────────────────────────────────────
    local function mkToggle(parent,lbl,y,get,set)
        local row=Instance.new("Frame",parent)
        row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,28) row.BackgroundTransparency=1
        local l=Instance.new("TextLabel",row) l.Size=UDim2.new(1,-54,1,0) l.BackgroundTransparency=1
        l.Text=lbl l.TextSize=13 l.TextColor3=Color3.fromRGB(210,210,210) l.Font=Enum.Font.Gotham
        l.TextXAlignment=Enum.TextXAlignment.Left
        local tog=Instance.new("TextButton",row)
        tog.Position=UDim2.new(1,-50,0.5,-13) tog.Size=UDim2.new(0,50,0,26)
        tog.BorderSizePixel=0 tog.Font=Enum.Font.GothamBold tog.TextSize=11
        corner(tog,13)
        local function ref()
            local v=get()
            tog.BackgroundColor3=v and Color3.fromRGB(65,185,65) or Color3.fromRGB(44,44,44)
            tog.TextColor3=v and Color3.fromRGB(14,14,14) or Color3.fromRGB(120,120,120)
            tog.Text=v and "ON" or "OFF"
        end
        ref() tog.MouseButton1Click:Connect(function() set(not get()) ref() end)
        return y+32
    end

    local function mkSlider(parent,lbl,y,mn,mx,get,set,sfx)
        sfx=sfx or ""
        local row=Instance.new("Frame",parent)
        row.Position=UDim2.new(0,10,0,y) row.Size=UDim2.new(1,-20,0,52) row.BackgroundTransparency=1
        local l=Instance.new("TextLabel",row) l.Size=UDim2.new(1,0,0,18) l.BackgroundTransparency=1
        l.Text=lbl..": "..get()..sfx l.TextSize=13 l.TextColor3=Color3.fromRGB(210,210,210)
        l.Font=Enum.Font.Gotham l.TextXAlignment=Enum.TextXAlignment.Left
        local track=Instance.new("Frame",row) track.Position=UDim2.new(0,0,0,26)
        track.Size=UDim2.new(1,0,0,8) track.BackgroundColor3=Color3.fromRGB(36,36,36) track.BorderSizePixel=0
        corner(track,4)
        local fill=Instance.new("Frame",track)
        fill.Size=UDim2.new((get()-mn)/(mx-mn),0,1,0)
        fill.BackgroundColor3=Color3.fromRGB(255,220,60) fill.BorderSizePixel=0 corner(fill,4)
        local knob=Instance.new("Frame",track)
        knob.Size=UDim2.new(0,14,0,14) knob.AnchorPoint=Vector2.new(0.5,0.5)
        knob.Position=UDim2.new((get()-mn)/(mx-mn),0,0.5,0)
        knob.BackgroundColor3=Color3.fromRGB(255,255,255) knob.BorderSizePixel=0 corner(knob,7)
        local dragging=false
        local function upd(x)
            local f=clamp((x-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
            local v=math.round(mn+f*(mx-mn)) set(v)
            fill.Size=UDim2.new(f,0,1,0) knob.Position=UDim2.new(f,0,0.5,0)
            l.Text=lbl..": "..v..sfx
        end
        track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true upd(i.Position.X) end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)
        UIS.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i.Position.X) end end)
        return y+58
    end

    local function mkSep(parent,txt,y)
        local f=Instance.new("Frame",parent) f.Position=UDim2.new(0,10,0,y)
        f.Size=UDim2.new(1,-20,0,18) f.BackgroundTransparency=1
        local l=Instance.new("TextLabel",f) l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1
        l.Text="— "..txt.." —" l.TextSize=11 l.TextColor3=Color3.fromRGB(90,90,90)
        l.Font=Enum.Font.GothamBold l.TextXAlignment=Enum.TextXAlignment.Left
        return y+22
    end

    local function mkInfo(parent,txt,col,y)
        local l=Instance.new("TextLabel",parent) l.Position=UDim2.new(0,10,0,y)
        l.Size=UDim2.new(1,-20,0,18) l.BackgroundTransparency=1 l.Text=txt l.TextSize=12
        l.TextColor3=col or Color3.fromRGB(100,100,100) l.Font=Enum.Font.Gotham
        l.TextXAlignment=Enum.TextXAlignment.Left
        return y+22
    end

    -- ── ESP TAB ───────────────────────────────────────────────
    do local t=tabFrames["ESP"] local y=8
        y=mkToggle(t,"ESP Enabled",  y,function() return CFG.ESP_ENABLED    end,function(v) CFG.ESP_ENABLED=v    end)
        y=mkSep(t,"Box & Text",y)
        y=mkToggle(t,"Box ESP",      y,function() return CFG.ESP_BOX        end,function(v) CFG.ESP_BOX=v        end)
        y=mkToggle(t,"Name Tag",     y,function() return CFG.ESP_NAME       end,function(v) CFG.ESP_NAME=v       end)
        y=mkToggle(t,"Distance",     y,function() return CFG.ESP_DISTANCE   end,function(v) CFG.ESP_DISTANCE=v   end)
        y=mkToggle(t,"Health Bar",   y,function() return CFG.ESP_HEALTH_BAR end,function(v) CFG.ESP_HEALTH_BAR=v end)
        y=mkToggle(t,"Tracers [F2]", y,function() return CFG.ESP_TRACER     end,function(v) CFG.ESP_TRACER=v     end)
        y=mkToggle(t,"Head Dot",     y,function() return CFG.ESP_HEAD_DOT   end,function(v) CFG.ESP_HEAD_DOT=v   end)
        y=mkSep(t,"Effects",y)
        y=mkToggle(t,"Skeleton",     y,function() return CFG.ESP_SKELETON   end,function(v) CFG.ESP_SKELETON=v   end)
        y=mkToggle(t,"Chams",        y,function() return CFG.ESP_CHAMS      end,function(v) CFG.ESP_CHAMS=v if not v then for _,h in pairs(ChamPool) do h.Enabled=false end end end)
        y=mkToggle(t,"Rainbow ESP",  y,function() return CFG.ESP_RAINBOW    end,function(v) CFG.ESP_RAINBOW=v    end)
        y=mkToggle(t,"Team Colors",  y,function() return CFG.TEAM_COLORS    end,function(v) CFG.TEAM_COLORS=v    end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- ── AIMBOT TAB ────────────────────────────────────────────
    do local t=tabFrames["Aimbot"] local y=8
        y=mkToggle(t,"Aimbot (RMB)",   y,function() return CFG.AIM_ENABLED   end,function(v) CFG.AIM_ENABLED=v   end)
        y=mkToggle(t,"Show FOV Circle",y,function() return CFG.AIM_SHOW_FOV  end,function(v) CFG.AIM_SHOW_FOV=v  end)
        y=mkToggle(t,"Prediction",     y,function() return CFG.AIM_PREDICTION end,function(v) CFG.AIM_PREDICTION=v end)
        y=mkToggle(t,"Auto Fire",      y,function() return CFG.AIM_AUTO_FIRE  end,function(v) CFG.AIM_AUTO_FIRE=v  end)
        y=mkSep(t,"Settings",y)
        y=mkSlider(t,"Smoothness",  y,1,30,  function() return CFG.AIM_SMOOTH end, function(v) CFG.AIM_SMOOTH=v end)
        y=mkSlider(t,"FOV Radius",  y,30,500, function() return CFG.AIM_FOV  end,  function(v) CFG.AIM_FOV=v fovCircle.Radius=v end,"px")
        y=mkSep(t,"Target Bone",y)
        -- Bone selector
        local boneRow=Instance.new("Frame",t) boneRow.Position=UDim2.new(0,10,0,y)
        boneRow.Size=UDim2.new(1,-20,0,30) boneRow.BackgroundTransparency=1
        local bones={{"Head","Head"},{"UpperTorso","Chest"},{"HumanoidRootPart","Root"}}
        local boneBtns={}
        for bi,bdata in ipairs(bones) do
            local bb=Instance.new("TextButton",boneRow)
            bb.Position=UDim2.new(0,(bi-1)*106,0,0) bb.Size=UDim2.new(0,100,0,28)
            bb.BorderSizePixel=0 bb.Text=bdata[2] bb.TextSize=12 bb.Font=Enum.Font.GothamBold
            corner(bb,4) boneBtns[bdata[1]]=bb
            bb.MouseButton1Click:Connect(function()
                CFG.AIM_BONE=bdata[1]
                for bn,b2 in pairs(boneBtns) do
                    b2.BackgroundColor3=bn==CFG.AIM_BONE and Color3.fromRGB(255,220,60) or Color3.fromRGB(36,36,36)
                    b2.TextColor3=bn==CFG.AIM_BONE and Color3.fromRGB(14,14,14) or Color3.fromRGB(150,150,150)
                end
            end)
        end
        for bn,b2 in pairs(boneBtns) do
            b2.BackgroundColor3=bn==CFG.AIM_BONE and Color3.fromRGB(255,220,60) or Color3.fromRGB(36,36,36)
            b2.TextColor3=bn==CFG.AIM_BONE and Color3.fromRGB(14,14,14) or Color3.fromRGB(150,150,150)
        end
        y=y+38
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- ── VISUALS TAB ───────────────────────────────────────────
    do local t=tabFrames["Visuals"] local y=8
        y=mkToggle(t,"No Muzzle Flash", y,function() return CFG.NO_MUZZLE  end,function(v) CFG.NO_MUZZLE=v  if not v then enableMuzzle() end end)
        y=mkToggle(t,"Fullbright",      y,function() return CFG.FULLBRIGHT  end,function(v) CFG.FULLBRIGHT=v  setFullbright(v) end)
        y=mkToggle(t,"No Fog",          y,function() return CFG.NO_FOG      end,function(v) CFG.NO_FOG=v      setNoFog(v)      end)
        y=mkToggle(t,"Crosshair",       y,function() return CFG.CROSSHAIR   end,function(v) CFG.CROSSHAIR=v   end)
        y=mkSep(t,"Settings",y)
        y=mkSlider(t,"Camera FOV",    y,50,120, function() return CFG.FOV_VALUE       end, function(v) CFG.FOV_VALUE=v       Camera.FieldOfView=v end,"°")
        y=mkSlider(t,"Crosshair Size",y,4,40,  function() return CFG.CROSSHAIR_SIZE  end, function(v) CFG.CROSSHAIR_SIZE=v  end,"px")
        y=mkSlider(t,"Crosshair Gap", y,0,20,  function() return CFG.CROSSHAIR_GAP   end, function(v) CFG.CROSSHAIR_GAP=v   end,"px")
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- ── PLAYER TAB ────────────────────────────────────────────
    do local t=tabFrames["Player"] local y=8
        y=mkSep(t,"Speed",y)
        y=mkToggle(t,"Speed Hack",    y,function() return CFG.SPEED_ENABLED end,function(v) CFG.SPEED_ENABLED=v pushNotif("Speed "..(v and "ON" or "OFF")) end)
        y=mkSlider(t,"Walk Speed",    y,1,200,  function() return CFG.SPEED_VALUE end, function(v) CFG.SPEED_VALUE=v end)
        y=mkSep(t,"Jump",y)
        y=mkToggle(t,"Jump Hack",     y,function() return CFG.JUMP_ENABLED  end,function(v) CFG.JUMP_ENABLED=v  pushNotif("Jump Hack "..(v and "ON" or "OFF")) end)
        y=mkSlider(t,"Jump Power",    y,1,300,  function() return CFG.JUMP_VALUE  end, function(v) CFG.JUMP_VALUE=v  end)
        y=mkSep(t,"Movement",y)
        y=mkToggle(t,"Infinite Jump", y,function() return CFG.INF_JUMP end,function(v) CFG.INF_JUMP=v pushNotif("Infinite Jump "..(v and "ON" or "OFF")) end)
        y=mkToggle(t,"Noclip",        y,function() return CFG.NOCLIP   end,function(v)
            CFG.NOCLIP=v
            if not v then
                local char=LP.Character if char then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=true end end end
            end
            pushNotif("Noclip "..(v and "ON" or "OFF"))
        end)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    -- ── MISC TAB ──────────────────────────────────────────────
    do local t=tabFrames["Misc"] local y=8
        y=mkToggle(t,"Anti-AFK",       y,function() return CFG.ANTI_AFK    end,function(v) CFG.ANTI_AFK=v    end)
        y=mkToggle(t,"Spectator List", y,function() return CFG.SPEC_LIST   end,function(v) CFG.SPEC_LIST=v   if not v then specLabel.Visible=false end end)
        y=mkToggle(t,"FPS Counter",    y,function() return CFG.FPS_COUNTER end,function(v) CFG.FPS_COUNTER=v if not v then fpsLabel.Visible=false   end end)
        y=mkSep(t,"Keybinds",y)
        y=mkInfo(t,"Insert  →  Toggle UI",nil,y)
        y=mkInfo(t,"Delete  →  Panic (all off)",nil,y)
        y=mkInfo(t,"RMB     →  Hold to aim",nil,y)
        y=mkInfo(t,"F2      →  Toggle tracers",nil,y)
        y=mkSep(t,"Credits",y)
        y=mkInfo(t,"Xreg Hub v2.0 — Defusal",Color3.fromRGB(255,220,60),y)
        y=mkInfo(t,"Key: XREG-2025",Color3.fromRGB(100,100,100),y)
        t.CanvasSize=UDim2.new(0,0,0,y+10)
    end

    setTab("ESP")

    -- Key entry
    kBtn.MouseButton1Click:Connect(function()
        if kBox.Text==KEY then
            kf.Visible=false mf.Visible=true
            pushNotif("Welcome to Xreg Hub",Color3.fromRGB(255,220,60))
        else kErr.Text="Wrong key." kBox.Text="" end
    end)
    kBox.FocusLost:Connect(function(enter)
        if enter and kBox.Text==KEY then
            kf.Visible=false mf.Visible=true
            pushNotif("Welcome to Xreg Hub",Color3.fromRGB(255,220,60))
        end
    end)
    UIS.InputBegan:Connect(function(inp,gpe)
        if gpe then return end
        if inp.KeyCode==Enum.KeyCode.Insert then mf.Visible=not mf.Visible end
    end)
end

-- ══════════════════════════════════════════════════════════════
-- RENDER LOOP
-- ══════════════════════════════════════════════════════════════
RunService.RenderStepped:Connect(function(dt)
    rainbowHue=(rainbowHue+dt*0.4)%1
    local vp=Camera.ViewportSize
    local sb=Vector2.new(vp.X/2,vp.Y-5)
    local sc=Vector2.new(vp.X/2,vp.Y/2)

    -- FOV circle
    fovCircle.Position=sc fovCircle.Radius=CFG.AIM_FOV
    fovCircle.Visible=CFG.AIM_ENABLED and CFG.AIM_SHOW_FOV

    -- Crosshair
    if CFG.CROSSHAIR then
        local sz=CFG.CROSSHAIR_SIZE local gp=CFG.CROSSHAIR_GAP
        CH.t.From=Vector2.new(sc.X,sc.Y-gp-sz) CH.t.To=Vector2.new(sc.X,sc.Y-gp) CH.t.Visible=true
        CH.b.From=Vector2.new(sc.X,sc.Y+gp)    CH.b.To=Vector2.new(sc.X,sc.Y+gp+sz) CH.b.Visible=true
        CH.l.From=Vector2.new(sc.X-gp-sz,sc.Y) CH.l.To=Vector2.new(sc.X-gp,sc.Y) CH.l.Visible=true
        CH.r.From=Vector2.new(sc.X+gp,sc.Y)    CH.r.To=Vector2.new(sc.X+gp+sz,sc.Y) CH.r.Visible=true
        CH.d.Position=sc CH.d.Visible=true
    else for _,l in pairs(CH) do l.Visible=false end end

    -- Aimbot
    if CFG.AIM_ENABLED and aiming then
        local target=getAimTarget()
        if target then
            local tpos=target.Position
            if CFG.AIM_PREDICTION then
                local vel=target:IsA("BasePart") and target.AssemblyLinearVelocity or Vector3.new()
                local d=(Camera.CFrame.Position-tpos).Magnitude
                tpos=tpos+vel*(d/500)
            end
            Camera.CFrame=Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position,tpos),clamp(CFG.AIM_SMOOTH/100,0.01,1))
            if CFG.AIM_AUTO_FIRE then
                local now=tick()
                if now-autoFireT>0.09 then autoFireT=now pcall(function() mouse1click() end) end
            end
        end
    end

    -- Muzzle
    if CFG.NO_MUZZLE then
        local now=tick() if now-muzzleT>0.08 then muzzleT=now disableMuzzle() end
    end

    -- Player ESP
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LP then continue end
        if not ESPPool[player] then ESPPool[player]=allocESP(player) end
        local obj=ESPPool[player]
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        if not char or not hum or hum.Health<=0 then
            hideESP(obj) if ChamPool[player] then ChamPool[player].Enabled=false end continue
        end
        local b=getCharBounds(char)
        if not b or not CFG.ESP_ENABLED then
            hideESP(obj) if ChamPool[player] then ChamPool[player].Enabled=false end continue
        end
        local color=CFG.ESP_RAINBOW and rainbow() or getTeamColor(player)
        local hp=clamp(hum.Health/hum.MaxHealth,0,1)
        local pad=Vector2.new(1,1)

        obj.boxOut.PointA=b.TL-pad obj.boxOut.PointB=b.TR+Vector2.new(1,-1)
        obj.boxOut.PointC=b.BR+pad obj.boxOut.PointD=b.BL+Vector2.new(-1,1) obj.boxOut.Visible=CFG.ESP_BOX
        obj.box.PointA=b.TL obj.box.PointB=b.TR obj.box.PointC=b.BR obj.box.PointD=b.BL
        obj.box.Color=color obj.box.Visible=CFG.ESP_BOX
        obj.name.Text=player.Name obj.name.Color=color
        obj.name.Position=Vector2.new(b.cx,b.TL.Y-16) obj.name.Visible=CFG.ESP_NAME
        obj.dist.Text=floor(b.dist).."m"
        obj.dist.Position=Vector2.new(b.cx,b.BL.Y+2) obj.dist.Visible=CFG.ESP_DISTANCE

        if CFG.ESP_HEALTH_BAR then
            local bx=b.TL.X-6 local bh=b.h local fh=bh*hp
            obj.hpBg.Position=Vector2.new(bx,b.TL.Y) obj.hpBg.Size=Vector2.new(4,bh) obj.hpBg.Visible=true
            obj.hpBar.Position=Vector2.new(bx,b.TL.Y+(bh-fh)) obj.hpBar.Size=Vector2.new(4,fh)
            obj.hpBar.Color=getHPColor(hp) obj.hpBar.Visible=true
        else obj.hpBg.Visible=false obj.hpBar.Visible=false end

        obj.tracer.From=sb obj.tracer.To=b.bot obj.tracer.Color=color obj.tracer.Visible=CFG.ESP_TRACER

        -- Head dot
        if CFG.ESP_HEAD_DOT then
            local head=char:FindFirstChild("Head")
            if head then
                local hsp,hon,hz=w2s(head.Position)
                if hon and hz>0 then
                    obj.headDot.Position=hsp obj.headDot.Color=color obj.headDot.Visible=true
                else obj.headDot.Visible=false end
            else obj.headDot.Visible=false end
        else obj.headDot.Visible=false end

        -- Skeleton
        if CFG.ESP_SKELETON then
            local boneSet=char:FindFirstChild("Torso") and R6 or R15
            local li=1
            for _,pair in ipairs(boneSet) do
                if li>#obj.skel then break end
                local b1=char:FindFirstChild(pair[1]) local b2=char:FindFirstChild(pair[2])
                if b1 and b2 then
                    local sp1,on1,z1=w2s(b1.Position) local sp2,on2,z2=w2s(b2.Position)
                    if (on1 or on2) and z1>0 and z2>0 then
                        local l=obj.skel[li] l.From=sp1 l.To=sp2 l.Color=color l.Visible=true li=li+1
                    end
                end
            end
            for i=li,#obj.skel do obj.skel[i].Visible=false end
        else for _,l in ipairs(obj.skel) do l.Visible=false end end

        -- Chams
        updateChams(player,color)
    end

    -- GC
    for player,obj in pairs(ESPPool) do
        if not Players:FindFirstChild(player.Name) then
            freeESP(obj) ESPPool[player]=nil
            if ChamPool[player] then ChamPool[player]:Destroy() ChamPool[player]=nil end
        end
    end

    -- Bomb
    local bombPart=findBomb()
    if CFG.ESP_ENABLED and bombPart then
        local sp,on,dist=w2s(bombPart.Position)
        if on and dist>0 then
            BombESP.label.Position=Vector2.new(sp.X,sp.Y-14)
            BombESP.label.Text=string.format("◆ BOMB  %.0fm",dist)
            BombESP.label.Visible=true
            BombESP.tracer.From=sb BombESP.tracer.To=sp BombESP.tracer.Visible=true
        else
            BombESP.label.Position=Vector2.new(clamp(sp.X,30,vp.X-30),clamp(sp.Y,30,vp.Y-30))
            BombESP.label.Text=string.format("▶ BOMB  %.0fm",dist or 0)
            BombESP.label.Visible=true BombESP.tracer.Visible=false
        end
    else BombESP.label.Visible=false BombESP.tracer.Visible=false end

    -- Spectator list
    if CFG.SPEC_LIST then
        local specs=getSpectators()
        if #specs>0 then
            specLabel.Text="👁  "..table.concat(specs,", ")
            specLabel.Position=Vector2.new(vp.X/2,8) specLabel.Center=true specLabel.Visible=true
        else specLabel.Visible=false end
    else specLabel.Visible=false end

    -- FPS
    if CFG.FPS_COUNTER then
        fpsLabel.Color=fpsCurrent>=50 and Color3.fromRGB(100,255,100)
            or fpsCurrent>=30 and Color3.fromRGB(255,200,50)
            or Color3.fromRGB(255,80,80)
        fpsLabel.Text="FPS "..fpsCurrent
        fpsLabel.Position=Vector2.new(vp.X-68,vp.Y-20) fpsLabel.Visible=true
    else fpsLabel.Visible=false end

    -- Notifications
    tickNotifs()
end)

makeGui()
print("[Xreg Hub v2.0] ready | XREG-2025 | Insert=UI | Delete=panic")
]==])()
