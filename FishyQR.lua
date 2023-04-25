FishyQR = {
    name = "FishyQR",
    author = "FishyESO"
}

--local logger = LibDebugLogger(FishyQR.name)
local gps = LibGPS3

--PARAMS:
local FishyQRparams = {}
local FishyQRdefaults = {
    pixelsize    = 8,
    maxpixels    = 25,
    updatetime   = 500,
    posx         = 0,
    posy         = 0,
    run_var      = false,
    change_scene = true,
    enabled_on_looking = true
}

local brdr = 10
local topPad = 12
local text = 20
local dimX = 0
local dimY = 0

-- QR -------------------------------

--draw qr
local function _drawQR(keyString)
    local ok, qrtable = qrcode(keyString)
    local tmpLastPixel = 0
    if ok then
        --set pixels
        for i,ref in pairs(qrtable) do
            tmpLastPixel = i
            for j,val in pairs(ref) do
                --Error: not enough pixels allocated
                if j > FishyQRparams.maxpixels then
                    return
                end

                if val < 0 then
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                else
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(false)
                end
            end
        end

        --make unused pixels blank
        if tmpLastPixel < FishyQRparams.maxpixels then
            for i = 1, tmpLastPixel do
                for j = tmpLastPixel+1, FishyQRparams.maxpixels do
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
            for i = tmpLastPixel+1, FishyQRparams.maxpixels do
                for j = 1, FishyQRparams.maxpixels do
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
        end

        --resize background
        FishyQR.UI.background:SetDimensions(dimX, dimY)
    end
end


local tmpKeyString = ""
local function _generateQR()
    --get the gps values and form them to a string
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
    
    -- add all data here
    -- if made changes to this, dont forget to update the parsing in qr_detection._parse_qr_code
    local keyString = string.format("%f,%f,%d,%d", x, y, angle, FishyQR.engine.currentState)

    --draw QRC with new location
    if tmpKeyString ~= keyString then
        tmpKeyString = keyString
        _drawQR(tmpKeyString)
    end
end


local function _stopState()
    FishyQR.UI.buttonLabel:SetText("↓")
    FishyQR.UI.background:SetDimensions(dimX, text + brdr)

    for i = 0,FishyQRparams.maxpixels-1 do
        for j = 0,FishyQRparams.maxpixels-1 do
            FishyQR.UI.pixel[i][j]:SetHidden(true)
        end
    end

    FishyQR.UI:SetDrawLayer(DL_MIN_VALUE)
    FishyQR.UI:SetDrawTier(DT_MIN_VALUE)
    
    EVENT_MANAGER:UnregisterForUpdate(FishyQR.name .. "generateQR", FishyQRparams.updatetime, _generateQR)
end


local function _startState()
    FishyQR.UI.background:SetDimensions(dimX, dimY)
    FishyQR.UI.buttonLabel:SetText("—")

    if FishyQR.UI.pixel ~= nil then
        tmpKeyString = ""
        _generateQR()
    end
    
    FishyQR.UI:SetDrawLayer(DL_MAX_VALUE-1)
    FishyQR.UI:SetDrawTier(DT_MAX_VALUE-1)

    EVENT_MANAGER:RegisterForUpdate(FishyQR.name .. "generateQR", FishyQRparams.updatetime, _generateQR)
end


local _hideOnSceneChange


local function _update_state()
    if FishyQR.running then
        _startState()
        if FishyQRparams.change_scene then
            HUD_SCENE:RegisterCallback("StateChange", _hideOnSceneChange)
        end
    else
        _stopState()
        HUD_SCENE:UnregisterCallback("StateChange", _hideOnSceneChange)
    end
end


_hideOnSceneChange = function(oldState, newState)
    if newState == SCENE_HIDDEN then
        if FishyQR.engine.currentState < FishyQR.engine.state.depleted or
           FishyQR.engine.currentState > FishyQR.engine.state.invfull
        then
            _stopState()
        end
    elseif newState == SCENE_SHOWN then
        _update_state()
    end
end


local function _enable_on_looking(state)
    if state == FishyQR.engine.state.looking then
        FishyQR.engine.CallbackManager:UnregisterCallback(FishyQR.engine.name .. "FishyCha_STATE_CHANGE", _enable_on_looking)
        FishyQR.running = true
        _update_state()
    end
end


function FishyQR.toggle_running_state()
    FishyQR.running = not FishyQR.running
    _update_state()

    if not FishyQR.running and FishyQRparams.enabled_on_looking then
        FishyQR.engine.CallbackManager:RegisterCallback(FishyQR.engine.name .. "FishyCha_STATE_CHANGE", _enable_on_looking)
    end
end


function _createUI()
    --create qr ui code elements
    dimX = brdr + FishyQRparams.maxpixels*FishyQRparams.pixelsize + brdr
    dimY = text + brdr + topPad + FishyQRparams.maxpixels*FishyQRparams.pixelsize + brdr

    FishyQR.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    FishyQR.UI:SetMouseEnabled(true)
    FishyQR.UI:SetClampedToScreen(true)
    FishyQR.UI:SetMovable(true)
    FishyQR.UI:SetDimensions(dimX, dimY)
    FishyQR.UI:SetDrawLevel(0)
    FishyQR.UI:SetDrawLayer(DL_MAX_VALUE-1)
    FishyQR.UI:SetDrawTier(DT_MAX_VALUE-1)

    FishyQR.UI:ClearAnchors()
    FishyQR.UI:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, FishyQRparams.posx, FishyQRparams.posy)

    FishyQR.UI.background = WINDOW_MANAGER:CreateControl(nil, FishyQR.UI, CT_TEXTURE)
    FishyQR.UI.background:SetDimensions(dimX, dimY)
    FishyQR.UI.background:SetColor(1, 1, 1)
    FishyQR.UI.background:SetAnchor(TOPLEFT, FishyQR.UI, TOPLEFT, 0, 0)
    FishyQR.UI.background:SetHidden(false)
    FishyQR.UI.background:SetDrawLevel(0)

    FishyQR.UI.label = WINDOW_MANAGER:CreateControl(FishyQR.name .. "label", FishyQR.UI, CT_LABEL)
    FishyQR.UI.label:SetFont("ZoFontChat")
    FishyQR.UI.label:SetColor(0,0,0)
    FishyQR.UI.label:SetAnchor(TOP, FishyQR.UI.background, TOP, 0, 0)
    FishyQR.UI.label:SetText("FishyQR")

    FishyQR.UI.buttonLabel = WINDOW_MANAGER:CreateControl(FishyQR.name .. "buttonLabel", FishyQR.UI, CT_LABEL)
    FishyQR.UI.buttonLabel:SetFont("ZoFontChat")
    FishyQR.UI.buttonLabel:SetColor(0,0,0)
    FishyQR.UI.buttonLabel:SetAnchor(TOPRIGHT, FishyQR.UI.background, TOPRIGHT, -brdr, 0)

    FishyQR.UI.button = WINDOW_MANAGER:CreateControl(FishyQR.name .. "button", FishyQR.UI, CT_BUTTON)
    FishyQR.UI.button:SetDimensions(text, text)
    FishyQR.UI.button:SetAnchor(TOPRIGHT, FishyQR.UI.background, TOPRIGHT, -brdr, 0)
    FishyQR.UI.button:SetHandler("OnClicked", FishyQR.toggle_running_state)

    FishyQR.UI.pixel = {}
    for i = 0,FishyQRparams.maxpixels-1 do
        FishyQR.UI.pixel[i] = {}
        for j = 0,FishyQRparams.maxpixels-1 do
            FishyQR.UI.pixel[i][j] = WINDOW_MANAGER:CreateControl(nil, FishyQR.UI, CT_TEXTURE)
            FishyQR.UI.pixel[i][j]:SetDimensions(FishyQRparams.pixelsize, FishyQRparams.pixelsize)
            FishyQR.UI.pixel[i][j]:SetColor(0, 0, 0)
            FishyQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, FishyQR.UI.background, TOPLEFT, brdr+(i*FishyQRparams.pixelsize), text+brdr+topPad+(j*FishyQRparams.pixelsize))
            FishyQR.UI.pixel[i][j]:SetHidden(true)
            FishyQR.UI.pixel[i][j]:SetDrawLevel(0)
        end
    end

    FishyQR.UI:SetHandler("OnMoveStop", function()
        FishyQRparams.posy = FishyQR.UI:GetTop()
        FishyQRparams.posx = FishyQR.UI:GetRight() - GuiRoot:GetRight()
    end)
end


function _createMenu()
    --#region addon menu
    --addon menu
    local LAM = LibAddonMenu2
    local panelName = FishyQR.name .. "Settings"

    local panelData = {
        type = "panel",
        name = FishyQR.name,
        author = FishyQR.author,
    }
    local panel = LAM:RegisterAddonPanel(panelName, panelData)
    local optionsData = {
        {
            type = "dropdown",
            name = "Start State",
            choices = {"enabled", "disabled"},
            getFunc = function() if FishyQRparams.run_var then return "enabled" end return "disabled" end,
            setFunc = function(var)
                if var == "enabled" then
                    FishyQRparams.run_var = true
                else
                    FishyQRparams.run_var = false
                end
            end,
            tooltip = "If enabled FishyQR will start immediately, when the game is loaded.",
        },
        {
            type = "dropdown",
            name = "Hide On Scene Change",
            choices = {"enabled", "disabled"},
            getFunc = function() if FishyQRparams.change_scene then return "enabled" end return "disabled" end,
            setFunc = function(var)
                if var == "enabled" then
                    FishyQRparams.change_scene = true
                    HUD_SCENE:RegisterCallback("StateChange", _hideOnSceneChange)
                else
                    FishyQRparams.change_scene = false
                    HUD_SCENE:UnregisterCallback("StateChange", _hideOnSceneChange)
                end
            end,
            tooltip = "If enabled FishyQR will hide when a menu is opened.",
        },
        {
            type = "dropdown",
            name = "Enable when looking at a fishing hole",
            choices = {"enabled", "disabled"},
            default = "enabled",
            getFunc = function() if FishyQRparams.enabled_on_looking then return "enabled" end return "disabled" end,
            setFunc = function(var)
                if var == "enabled" then
                    FishyQRparams.enabled_on_looking = true
                    FishyQR.engine.CallbackManager:RegisterCallback(FishyQR.engine.name .. "FishyCha_STATE_CHANGE", _enable_on_looking)
                else
                    FishyQR.engine.CallbackManager:UnregisterCallback(FishyQR.engine.name .. "FishyCha_STATE_CHANGE", _enable_on_looking)
                    FishyQRparams.enabled_on_looking = false
                end
            end,
            tooltip = "If enabled FishyQR will automatically start when the player is looking at a fishing hole.",
        },
        {
            type = "slider",
            name = "Pixel Size",
            min = 1,
            max = 8,
            default = 8,
            getFunc = function() return FishyQRparams.pixelsize end,
            setFunc = function(value)
                FishyQRparams.pixelsize = value
                FishyQR.UI:SetDimensions(2*brdr + FishyQRparams.maxpixels*FishyQRparams.pixelsize, 3*brdr + FishyQRparams.maxpixels*FishyQRparams.pixelsize + text)
                FishyQR.UI.background:SetDimensions(2*brdr + FishyQRparams.maxpixels*FishyQRparams.pixelsize, 3*brdr + FishyQRparams.maxpixels*FishyQRparams.pixelsize + text)
                for i = 0,FishyQRparams.maxpixels-1 do
                    for j = 0,FishyQRparams.maxpixels-1 do
                        FishyQR.UI.pixel[i][j]:SetDimensions(FishyQRparams.pixelsize, FishyQRparams.pixelsize)
                        FishyQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, FishyQR.UI.background, TOPLEFT, brdr+(i*FishyQRparams.pixelsize), brdr+(j*FishyQRparams.pixelsize))
                    end
                end
            end,
            tooltip = "Set the size of each pixel of the QR Code.",
            requiresReload = true
        },
        {
            type = "slider",
            name = "Updatetime",
            min = 150,
            max = 1500,
            step = 50,
            default = 500,
            getFunc = function() return FishyQRparams.updatetime end,
            setFunc = function(value) FishyQRparams.updatetime = value end,
            tooltip = "Set the wait time between each QR Code Update in ms.",
            requiresReload = true
        },
        {
            type = "description",
            title = "NOTE",
            text = "If you experience problems with performance, try increasing Updatetime. The higher the value of Updatetime is, the less it will draw performance.",
            width = "full"
        }
    }
    LAM:RegisterOptionControls(panelName, optionsData)
    ZO_CreateStringId("SI_BINDING_NAME_FISHYQRTOGGLE", "Toggle FishyQR")
    --#endregion
end


-- INIT -----------------------------
function FishyQR.OnAddOnLoaded(event, addonName)
    if addonName == FishyQR.name then
        --init once and never come here again
        EVENT_MANAGER:UnregisterForEvent(FishyQR.name, EVENT_ADD_ON_LOADED)

        --load params variable
        FishyQRparams = ZO_SavedVars:NewAccountWide("FishyQRparamsvar", 2, nil, FishyQRdefaults)

        --init chalutier
        fishyChaInit()
        FishyQR.engine = FishyCha

        FishyQR.running = FishyQRparams.run_var

        _createUI()
        _createMenu()

        if FishyQRparams.enabled_on_looking then
            FishyQR.engine.CallbackManager:RegisterCallback(FishyQR.engine.name .. "FishyCha_STATE_CHANGE", _enable_on_looking)
        end

        _update_state()
    end
end


EVENT_MANAGER:RegisterForEvent(FishyQR.name, EVENT_ADD_ON_LOADED, FishyQR.OnAddOnLoaded)
