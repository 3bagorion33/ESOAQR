ESOAQR = {
    name = "ESOAQR",
    author = "FishyESO"
}

--local logger = LibDebugLogger(ESOAQR.name)
local gps = LibGPS3

--PARAMS:
local ESOAQRparams = {}
local ESOAQRdefaults = {
    pixelsize    = 16,
    maxpixels    = 25,
    updatetime   = 20,
    posx         = 0,
    posy         = 0,
    run_var      = false,
    change_scene = false,
    enabled_on_looking = false
}

local brdr = 10
local topPad = 12
local text = 20
local dimX = 0
local dimY = 0

-- QR -------------------------------

--draw qr
local function _drawQR(keyString)
    local ui = ESOAQR.UI
    local maxpx = ESOAQRparams.maxpixels

    local ok, qrtable = qrcode(keyString)
    local tmpLastPixel = 0
    if ok then
        --set pixels
        for i,ref in pairs(qrtable) do
            tmpLastPixel = i
            for j,val in pairs(ref) do
                --Error: not enough pixels allocated
                if j > maxpx then
                    return
                end

                if val < 0 then
                    ui.pixel[i-1][j-1]:SetHidden(true)
                else
                    ui.pixel[i-1][j-1]:SetHidden(false)
                end
            end
        end

        --make unused pixels blank
        if tmpLastPixel < maxpx then
            for i = 1, tmpLastPixel do
                for j = tmpLastPixel+1, maxpx do
                    ui.pixel[i-1][j-1]:SetHidden(true)
                end
            end
            for i = tmpLastPixel+1, maxpx do
                for j = 1, maxpx do
                    ui.pixel[i-1][j-1]:SetHidden(true)
                end
            end
        end

        --resize background
        ui.background:SetDimensions(dimX, dimY)
    end
end


local tmpKeyString = ""
local function _generateQR()
    --get the gps values and form them to a string
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    --local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
	local angle = 360 - math.deg(GetPlayerCameraHeading())

    -- add all data here
    -- if made changes to this, dont forget to update the parsing in qr_detection._parse_qr_code
    local keyString = string.format("%f,%f,%d,%d", x, y, angle, ESOAQR.engine:getState())

    --draw QRC with new location
    if tmpKeyString ~= keyString then
        tmpKeyString = keyString
        _drawQR(tmpKeyString)
    end
end


local function _stopState()
    local this = ESOAQR
    local ui = this.UI
    local maxpx = ESOAQRparams.maxpixels

    --ui.buttonLabel:SetText("↓")
    ui.background:SetDimensions(0, 0)

    for i = 0,maxpx-1 do
        for j = 0,maxpx-1 do
            ui.pixel[i][j]:SetHidden(true)
        end
    end

    ui:SetDrawLayer(DL_MIN_VALUE)
    ui:SetDrawTier(DT_MIN_VALUE)

    EVENT_MANAGER:UnregisterForUpdate(this.name .. "generateQR")
    this.engine:unregisterOnStateChange(_generateQR)
end


local function _startState()
    local this = ESOAQR
    local ui = this.UI

    ui.background:SetDimensions(dimX, dimY)
    --ui.buttonLabel:SetText("—")

    if ui.pixel ~= nil then
        tmpKeyString = ""
        _generateQR()
    end

    ui:SetDrawLayer(DL_MAX_VALUE-1)
    ui:SetDrawTier(DT_MAX_VALUE-1)

    EVENT_MANAGER:RegisterForUpdate(this.name .. "generateQR", ESOAQRparams.updatetime, _generateQR)
    this.engine:registerOnStateChange(_generateQR)
end


--forward declaration due to circular function calls
local _hideOnSceneChange

local function _update_state()
    if ESOAQR.running then
        _startState()
        if ESOAQRparams.change_scene then
            HUD_SCENE:RegisterCallback("StateChange", _hideOnSceneChange)
        end
    else
        _stopState()
        HUD_SCENE:UnregisterCallback("StateChange", _hideOnSceneChange)
    end
end


_hideOnSceneChange = function(oldState, newState)
    local this = ESOAQR

    if newState == SCENE_HIDDEN then
        if this.engine:getState() < this.engine.state.depleted or
           this.engine:getState() > this.engine.state.invfull
        then
            _stopState()
        end
    elseif newState == SCENE_SHOWN then
        _update_state()
    end
end


local function _enable_on_looking(state)
    local this = ESOAQR

    if state == this.engine.state.looking then
        this.engine:unregisterOnStateChange(_enable_on_looking)
        this.running = true
        _update_state()
    end
end


function ESOAQR.toggle_running_state()
    local this = ESOAQR

    this.running = not this.running
    _update_state()

    if not this.running and ESOAQRparams.enabled_on_looking then
        this.engine:registerOnStateChange(_enable_on_looking)
    end
end


local function _createUI()
    local this = ESOAQR
    this.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
    local ui = this.UI
    local params = ESOAQRparams

    --create qr ui code elements
    dimX = brdr + params.maxpixels*params.pixelsize + brdr
    dimY = text + brdr + topPad + params.maxpixels*params.pixelsize + brdr

    ui:SetMouseEnabled(true)
    ui:SetClampedToScreen(true)
    ui:SetMovable(true)
    ui:SetDimensions(dimX, dimY)
    ui:SetDrawLevel(0)
    ui:SetDrawLayer(DL_MAX_VALUE-1)
    ui:SetDrawTier(DT_MAX_VALUE-1)

    ui:ClearAnchors()
    ui:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, params.posx, params.posy)

    ui.background = WINDOW_MANAGER:CreateControl(nil, ui, CT_TEXTURE)
    ui.background:SetDimensions(dimX, dimY)
    ui.background:SetColor(1, 1, 1)
    ui.background:SetAnchor(TOPLEFT, ui, TOPLEFT, 0, 0)
    ui.background:SetHidden(false)
    ui.background:SetDrawLevel(0)

    --ui.label = WINDOW_MANAGER:CreateControl(this.name .. "label", ui, CT_LABEL)
    --ui.label:SetFont("ZoFontChat")
    --ui.label:SetColor(0,0,0)
    --ui.label:SetAnchor(TOP, ui.background, TOP, 0, 0)
    --ui.label:SetText("ESOAQR")

    --ui.buttonLabel = WINDOW_MANAGER:CreateControl(this.name .. "buttonLabel", ui, CT_LABEL)
    --ui.buttonLabel:SetFont("ZoFontChat")
    --ui.buttonLabel:SetColor(0,0,0)
    --ui.buttonLabel:SetAnchor(TOPRIGHT, ui.background, TOPRIGHT, -brdr, 0)

    ui.button = WINDOW_MANAGER:CreateControl(this.name .. "button", ui, CT_BUTTON)
    ui.button:SetDimensions(text, text)
    ui.button:SetAnchor(TOPRIGHT, ui.background, TOPRIGHT, -brdr, 0)
    ui.button:SetHandler("OnClicked", ESOAQR.toggle_running_state)

    ui.pixel = {}
    for i = 0,params.maxpixels-1 do
        ui.pixel[i] = {}
        for j = 0,params.maxpixels-1 do
            ui.pixel[i][j] = WINDOW_MANAGER:CreateControl(nil, ui, CT_TEXTURE)
            ui.pixel[i][j]:SetDimensions(params.pixelsize, params.pixelsize)
            ui.pixel[i][j]:SetColor(0, 0, 0)
            ui.pixel[i][j]:SetAnchor(TOPLEFT, ui.background, TOPLEFT, brdr+(i*params.pixelsize), text+brdr+topPad+(j*params.pixelsize))
            ui.pixel[i][j]:SetHidden(true)
            ui.pixel[i][j]:SetDrawLevel(0)
        end
    end

    ui:SetHandler("OnMoveStop", function()
        params.posy = ui:GetTop()
        params.posx = ui:GetRight() - GuiRoot:GetRight()
    end)
end


function _createMenu()
    local this = ESOAQR
    local ui = this.UI
    local params = ESOAQRparams

    --#region addon menu
    --addon menu
    local LAM = LibAddonMenu2
    local panelName = this.name .. "Settings"

    local panelData = {
        type = "panel",
        name = this.name,
        author = this.author,
    }
    local panel = LAM:RegisterAddonPanel(panelName, panelData)
    local optionsData = {
        {
            type = "checkbox",
            name = "Start State",
            default = false,
            getFunc = function() return params.run_var end,
            setFunc = function(value) params.run_var = value end,
            tooltip = "If enabled ESOAQR will start immediately, when the game is loaded.",
        },
        {
            type = "checkbox",
            name = "Hide On Scene Change",
            default = false,
            getFunc = function() return params.change_scene end,
            setFunc = function(value)
                params.change_scene = value
                if value then
                    HUD_SCENE:RegisterCallback("StateChange", _hideOnSceneChange)
                    this.running = false
                else
                    HUD_SCENE:UnregisterCallback("StateChange", _hideOnSceneChange)
                    this.running = true
                end
                _update_state()
            end,
            tooltip = "If enabled ESOAQR will hide when a menu is opened.",
        },
        {
            type = "checkbox",
            name = "Enable when looking at a fishing hole",
            default = false,
            getFunc = function() return params.enabled_on_looking end,
            setFunc = function(value)
                params.enabled_on_looking = value
                if value then
                    this.engine:registerOnStateChange(_enable_on_looking)
                else
                    this.engine:unregisterOnStateChange(_enable_on_looking)
                end
            end,
            tooltip = "If enabled ESOAQR will automatically start when the player is looking at a fishing hole.",
        },
        {
            type = "slider",
            name = "Pixel Size",
            min = 1,
            max = 16,
            default = 8,
            getFunc = function() return params.pixelsize end,
            setFunc = function(value)
                params.pixelsize = value
                dimX = brdr + params.maxpixels*params.pixelsize + brdr
                dimY = text + brdr + topPad + params.maxpixels*params.pixelsize + brdr
                ui:SetDimensions(dimX, dimY)
                ui.background:SetDimensions(dimX, dimY)
                for i = 0,params.maxpixels-1 do
                    for j = 0,params.maxpixels-1 do
                        ui.pixel[i][j]:SetDimensions(params.pixelsize, params.pixelsize)
                        ui.pixel[i][j]:SetAnchor(TOPLEFT, ui.background, TOPLEFT, brdr+(i*params.pixelsize), brdr+(j*params.pixelsize)+text+topPad)
                    end
                end
            end,
            tooltip = "Set the size of each pixel of the QR Code."
        },
        {
            type = "slider",
            name = "Updatetime",
            min = 0,
            max = 100,
            step = 5,
            default = 20,
            getFunc = function() return params.updatetime end,
            setFunc = function(value)
                EVENT_MANAGER:UnregisterForUpdate(this.name .. "generateQR")
                params.updatetime = value
                if this.running then
                    EVENT_MANAGER:RegisterForUpdate(this.name .. "generateQR", value, _generateQR)
                end
            end,
            tooltip = "Set the wait time between each QR Code Update in ms."
        },
        {
            type = "description",
            title = "NOTE",
            text = "If you experience problems with performance, try increasing Updatetime. The higher the value of Updatetime is, the less it will draw performance.",
            width = "full"
        }
    }
    LAM:RegisterOptionControls(panelName, optionsData)
    ZO_CreateStringId("SI_BINDING_NAME_ESOAQRTOGGLE", "Toggle ESO Assistant QR")
    --#endregion
end


-- INIT -----------------------------
local function _onAddOnLoaded(event, addonName)
    if addonName == ESOAQR.name then
        --init once and never come here again
        EVENT_MANAGER:UnregisterForEvent(ESOAQR.name, EVENT_ADD_ON_LOADED)

        --load params variable
        ESOAQRparams = ZO_SavedVars:NewAccountWide("ESOAQRparamsvar", 2, nil, ESOAQRdefaults)

        --init chalutier
        ESOAQR.engine = FishingStateMachine

        ESOAQR.running = ESOAQRparams.run_var

        _createUI()
        _createMenu()

        if ESOAQRparams.enabled_on_looking then
            ESOAQR.engine:registerOnStateChange(_enable_on_looking)
        end

        _update_state()
    end
end


EVENT_MANAGER:RegisterForEvent(ESOAQR.name, EVENT_ADD_ON_LOADED, _onAddOnLoaded)
