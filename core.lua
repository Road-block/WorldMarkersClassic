local addonName, wmc, _ = ...

local addon = LibStub("AceAddon-3.0"):NewAddon(wmc,addonName, "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName)
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local ADBO = LibStub("AceDBOptions-3.0")
local LDBO = LibStub("LibDataBroker-1.1"):NewDataObject(addonName)
local LDI = LibStub("LibDBIcon-1.0")
addon._version = C_AddOns.GetAddOnMetadata(addonName,"Version")
addon._addonName = addonName.." "..addon._version
addon._addonNameC = LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(addon._addonName)
addon._shortLabel = LIGHTBLUE_FONT_COLOR:WrapTextInColorCode("WMC")
local _p = {}
local WORLD_MARKER_ORDER = {
  [1] = 6,
  [2] = 4,
  [3] = 3,
  [4] = 7,
  [5] = 1,
}
local NUM_WORLD_MARKERS = #WORLD_MARKER_ORDER
local classColors = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)
_p.marker_textures = {}
_p.button_hints = {}
do
  for marker_id,charm_id in pairs(WORLD_MARKER_ORDER) do
    _p.marker_textures[marker_id] = string.format("Interface\\TargetingFrame\\UI-RaidTargetingIcon_%d",charm_id)
    _p.button_hints[marker_id] = {
      string.format("%s %s",L["|cffffffffClick|r to place"],_G["WORLD_MARKER"..marker_id]),
      string.format("%s %s",L["|cffffffffRight-Click|r to remove"],_G["WORLD_MARKER"..marker_id]),
    }
  end
  _p.button_hints[NUM_WORLD_MARKERS+1] = {_G.REMOVE_WORLD_MARKERS}
end
_p.spell_data = {
  [84996] = 1,
  [84997] = 2,
  [84998] = 3,
  [84999] = 4,
  [85000] = 5,
}
_p.defaults = {
  global = {
    minimap = {hide = false,},
    lock = false,
  },
  profile = {
    btnSize = 26,
    border = 4,
    orientation = "VERTICAL",
    snitch = true,
    point = "LEFT",
    x = 10,
    y = 0,
  },
}
_p.consolecmd = {type = "group", handler = addon, args = {
  lock = {type="execute",name=L.CMD_LOCK,desc=L.CMD_LOCK,func=function()addon:ToggleLocked(nil,true)end,order=1},
  reset = {type="execute",name=_G.RESET,desc=L.CMD_RESET,func=function()end,order=2},
}}
_p.marker_colorcodes = {
  [1]="|cff0070dd",
  [2]="|cff1eff00",
  [3]="|cffa335ee",
  [4]="|cffff2020",
  [5]="|cffffff00",
}
local function textRainbow(text)
  local color_ctr = 0
  local rainbow = text:gsub(".",function(c)
    if c:match("%S") then
      color_ctr = color_ctr + 1 > #_p.marker_colorcodes and 1 or color_ctr + 1
      return _p.marker_colorcodes[color_ctr]..c..FONT_COLOR_CODE_CLOSE
    else
      return c
    end
  end)
  return rainbow
end

_p.combat_queue = {}
function addon:addToCombatQueue(method)
  if not tContains(_p.combat_queue,method) then
    addon:RegisterEvent("PLAYER_REGEN_ENABLED")
    table.insert(_p.combat_queue,method)
  end
end

function addon:applyUI()
  if not _p.UI then return end
  if InCombatLockdown() then
    self:addToCombatQueue("applyUI")
    return
  else
    _p.UI:ApplyLayout()
  end
end

function addon:Print(msg)
  local chatFrame = (SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
  local out = string.format("%s: %s",self._shortLabel,msg)
  chatFrame:AddMessage(out)
end

function addon:createUI()
  if _p.UI then return _p.UI end
  if InCombatLockdown() then
    self:addToCombatQueue("createUI")
    return
  else
    local BarMixin = {}
    function BarMixin:ApplyLayout()
      local btnSize, border = addon.db.profile.btnSize, addon.db.profile.border
      local bar_long = btnSize * (NUM_WORLD_MARKERS+1) + border * 2
      local bar_short = btnSize + border * 2
      local bar_width, bar_height
      local anchor
      if addon.db.profile.orientation == "HORIZONTAL" then
        bar_width = bar_long
        bar_height = bar_short
        anchor = "LEFT"
      elseif addon.db.profile.orientation == "VERTICAL" then
        bar_width = bar_short
        bar_height = bar_long
        anchor = "TOP"
      end
      self.bg:SetPoint("TOPLEFT", border,-border)
      self.bg:SetPoint("BOTTOMRIGHT",-border, border)
      self:SetSize(bar_width, bar_height)
      self:ClearAllPoints()
      self:SetPoint(addon.db.profile.point, UIParent, addon.db.profile.relPoint, addon.db.profile.x, addon.db.profile.y)
      local num_buttons = #self.buttons
      for i=1, num_buttons do
        local offset = (i == 1) and border or (border+(i-1)*btnSize)
        local offx, offy
        if anchor == "LEFT" then
          offx = offset
          offy = 0
        elseif anchor == "TOP" then
          offx = 0
          offy = -offset
        end
        self.buttons[i]:SetSize(btnSize,btnSize)
        self.buttons[i]:ClearAllPoints()
        self.buttons[i]:SetPoint(anchor, offx, offy)
      end
    end
    function BarMixin:Lock(verbose)
      self:StopMovingOrSizing()
      self:SetMovable(false)
      self.locked = true
      self:SetScript("OnMouseDown",nil)
      self:SetScript("OnMouseUp",nil)
      self:SetScript("OnHide",nil)
      addon.db.global.lock = true
      addon.db.profile.point, _, addon.db.profile.relPoint, addon.db.profile.x, addon.db.profile.y = self:GetPoint()
      if verbose then
        addon:Print(L["Locked"])
      end
    end
    function BarMixin:Unlock(verbose)
      self:SetMovable(true)
      self.locked = false
      self:SetScript("OnMouseDown",function(f,button)
        if InCombatLockdown() then return end
        self:StartMoving()
      end)
      self:SetScript("OnMouseUp",function(f,button)
        if InCombatLockdown() then return end
        self:StopMovingOrSizing()
      end)
      self:SetScript("OnHide",function(f)
        if InCombatLockdown() then return end
        self:StopMovingOrSizing()
      end)
      addon.db.global.lock = false
      if verbose then
        addon:Print(L["Unlocked. Drag by edge."])
      end
    end
    function BarMixin:CreateButtons()
      self.buttons = self.buttons or {}
      for marker=1,NUM_WORLD_MARKERS do
        self.buttons[marker]=CreateFrame("Button","WorldMarkerClassicButton"..marker, self, "SecureActionButtonTemplate,UIPanelSquareButton")
        self.buttons[marker]:SetAttribute("type","worldmarker")
        self.buttons[marker]:SetAttribute("action1","set")
        self.buttons[marker]:SetAttribute("action2","clear")
        self.buttons[marker]:SetAttribute("marker",marker)
        self.buttons[marker].icon:SetTexture(_p.marker_textures[marker])
        self.buttons[marker].icon:SetTexCoord(0,1,0,1)
        self.buttons[marker]:RegisterForClicks("AnyUp","AnyDown")
        self.buttons[marker]:SetScript("OnEnter",function(f)
          GameTooltip:SetOwner(f,"ANCHOR_CURSOR")
          GameTooltip:SetText(addon._shortLabel)
          for _,line in ipairs(_p.button_hints[marker]) do
            GameTooltip:AddLine(line)
          end
          GameTooltip:Show()
        end)
        self.buttons[marker]:SetScript("OnLeave",function(f)
          if GameTooltip:IsOwned(f) then
            GameTooltip_Hide()
          end
        end)
        self.buttons[marker]:SetScript("OnHide",function(f)
          if GameTooltip:IsOwned(f) then
            GameTooltip_Hide()
          end
        end)
      end
      local clear_id = NUM_WORLD_MARKERS+1
      self.buttons[clear_id]=CreateFrame("Button","WorldMarkerClassicButton"..clear_id, self, "SecureActionButtonTemplate,UIPanelSquareButton")
      self.buttons[clear_id]:SetAttribute("type","worldmarker")
      self.buttons[clear_id]:SetAttribute("action","clear")
      self.buttons[clear_id]:SetAttribute("marker",0)
      self.buttons[clear_id].icon:SetVertexColor(1,0,0,0.9)
      self.buttons[clear_id]:RegisterForClicks("AnyUp","AnyDown")
      self.buttons[clear_id]:SetScript("OnEnter",function(f)
        GameTooltip:SetOwner(f,"ANCHOR_CURSOR")
        GameTooltip:SetText(addon._shortLabel)
        for _,line in ipairs(_p.button_hints[clear_id]) do
          GameTooltip:AddLine(line)
        end
        GameTooltip:Show()
      end)
      self.buttons[clear_id]:SetScript("OnLeave",function(f)
        if GameTooltip:IsOwned(f) then
          GameTooltip_Hide()
        end
      end)
      self.buttons[clear_id]:SetScript("OnHide",function(f)
        if GameTooltip:IsOwned(f) then
          GameTooltip_Hide()
        end
      end)
    end

    local container = CreateFrame("Frame", "WorldMarkersClassicContainerFrame", UIParent, "SecureHandlerStateTemplate,BackdropTemplate")
    container.border=container:CreateTexture(nil,"BACKGROUND")
    container.border:SetColorTexture(0,1,0,0.5)
    container.border:SetAllPoints()
    container.bg=container:CreateTexture(nil,"BORDER")
    container.bg:SetColorTexture(0,0,0,1)
    container.locked = false
    Mixin(container,BarMixin)

    container:CreateButtons()

    container:SetPoint(addon.db.profile.point, UIParent, addon.db.profile.relPoint, addon.db.profile.x, addon.db.profile.y)
    container:Hide()

    RegisterStateDriver(container,"visibility","[group]show;hide")

    _p.UI = container
    return _p.UI

  end
end

local bindButtons = {}
function addon:bindButtons()
  if #bindButtons > 0 then return end
  if InCombatLockdown() then
    self:addToCombatQueue("bindButtons")
  else
    for marker=1,NUM_WORLD_MARKERS do
      bindButtons[marker] = CreateFrame("Button","WorldMarkerClassicBindButton"..marker, UIParent, "SecureActionButtonTemplate")
      bindButtons[marker]:SetAttribute("type","macro")
      bindButtons[marker]:SetAttribute("macrotext1","/wm [@cursor] "..marker)
      bindButtons[marker]:SetAttribute("macrotext2","/cwm "..marker)
    end
    local clear_id = NUM_WORLD_MARKERS+1
    local multi_id = clear_id + 1
    bindButtons[clear_id] = CreateFrame("Button","WorldMarkerClassicBindButtonClear", UIParent, "SecureActionButtonTemplate")
    bindButtons[clear_id]:SetAttribute("type","worldmarker")
    bindButtons[clear_id]:SetAttribute("action","clear")
    bindButtons[clear_id]:SetAttribute("marker",0)

    bindButtons[multi_id] = CreateFrame("Button","WorldMarkerClassicBindButtonMulti", UIParent, "SecureActionButtonTemplate")
    bindButtons[multi_id]:SetAttribute("type","macro")
    bindButtons[multi_id]:SetAttribute("macrotext","/wm [@cursor] 1")
    local snippet = string.format([[id = (id or 1)%%%d+1 self:SetAttribute("macrotext","/wm [@cursor] "..id)]],NUM_WORLD_MARKERS)
    SecureHandlerWrapScript(bindButtons[multi_id],"PostClick",bindButtons[multi_id],snippet)
  end
end

function addon:ToggleOptionsFrame()
  if ACD.OpenFrames[addonName] then
    ACD:Close(addonName)
  else
    ACD:Open(addonName,"general")
  end
end

function addon:ToggleLocked(status,verbose)
  if _p.UI then
    if status == nil then
      _p.UI[(_p.UI.locked and "Unlock" or "Lock")](_p.UI,verbose)
    elseif status == true then
      _p.UI:Lock(verbose)
    else
      _p.UI:Unlock(verbose)
    end
  end
end

function addon:SetNotification()
  if self.db.profile.snitch then
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  else
    self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  end
end

function addon:RefreshConfig()

end

function addon:GetOptionTable()
  if _p.Options and type(_p.Options)=="table" then return _p.Options end
   _p.Options = {type = "group", handler = addon, args = {
    general = {
      type = "group",
      name = _G.OPTIONS,
      childGroups = "tab",
      args = {
        main = {
          type = "group",
          name = _G.GENERAL,
          order = 1,
          args = { },
        },
      }
    }
  }}
  _p.Options.args.general.args.main.args.minimap = {
    type = "toggle",
    name = L["Hide from Minimap"],
    desc = L["Hide from Minimap"],
    order = 10,
    get = function() return not not addon.db.global.minimap.hide end,
    set = function(info, val)
      addon.db.global.minimap.hide = not addon.db.global.minimap.hide
    end,
  }
  _p.Options.args.general.args.main.args.lock = {
    type = "toggle",
    name = L["Locked"],
    desc = L["Locked"],
    order = 20,
    get = function() return not not addon.db.global.lock end,
    set = function(info, val)
      addon.db.global.lock = not addon.db.global.lock
      addon:ToggleLocked(addon.db.global.lock,true)
    end,
  }
  _p.Options.args.general.args.main.args.btnSize = {
    type = "input",
    name = L["Button Size"],
    desc = L["Button Size"],
    order = 30,
    width = 0.5,
    get = function() return tostring(addon.db.profile.btnSize) end,
    set = function(info, val)
      addon.db.profile.btnSize = tonumber(val)
      addon:applyUI()
    end,
  }
  _p.Options.args.general.args.main.args.border = {
    type = "range",
    name = L["Border Size"],
    desc = L["Increase Border size temporarily if you're having trouble dragging."],
    order = 35,
    get = function() return addon.db.profile.border end,
    set = function(info, val)
      addon.db.profile.border = tonumber(val)
      local size = math.floor(val)
      addon:applyUI()
    end,
    min = 0,
    max = 8,
    step = 1,
  }
  _p.Options.args.general.args.main.args.orientation = {
    type = "select",
    name = L["Orientation"],
    desc = L["Orientation"],
    order = 40,
    width = 0.8,
    get = function() return addon.db.profile.orientation end,
    set = function(info, val)
      addon.db.profile.orientation = val
      addon:applyUI()
    end,
    values = {["HORIZONTAL"]="Horizontal",["VERTICAL"]="Vertical",},
  }
  _p.Options.args.general.args.main.args.snitch = {
    type = "toggle",
    name = L["Notify Marker"],
    desc = L["Notify a World Marker was placed"],
    order = 45,
    get = function() return not not addon.db.profile.snitch end,
    set = function(info, val)
      addon.db.profile.snitch = not addon.db.profile.snitch
      addon:SetNotification()
    end,
  }
  return _p.Options
end

function addon:OnInitialize() -- ADDON_LOADED

  self.db = LibStub("AceDB-3.0"):New("WorldMarkersClassicDB", _p.defaults)
  _p.Options = self:GetOptionTable()
  _p.Options.args.profile = ADBO:GetOptionsTable(self.db)
  _p.Options.args.profile.guiHidden = true
  _p.Options.args.profile.cmdHidden = true
  AC:RegisterOptionsTable(addonName.."_cmd", _p.consolecmd, {addonName:lower(),"wmc"})
  AC:RegisterOptionsTable(addonName, _p.Options)
  self.blizzoptions = ACD:AddToBlizOptions(addonName,nil,nil,"general")
  self.blizzoptions.profile = ACD:AddToBlizOptions(addonName, "Profiles", addonName, "profile")
  self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
  self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
  self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

  LDBO.type = "launcher"
  LDBO.text = addonName
  LDBO.label = addon._addonNameC
  LDBO.icon = 134284 -- purple smoke flare
  LDBO.OnClick = addon.OnLDBClick
  LDBO.OnTooltipShow = addon.OnLDBTooltipShow
  LDI:Register(addonName, LDBO, addon.db.global.minimap)

  _p.UI = self:createUI()

  self:bindButtons()
end

function addon:OnEnable() -- PLAYER_LOGIN
  self:applyUI()
  self:ToggleLocked(not not addon.db.global.lock)
  self:SetNotification()
end

function addon.OnLDBClick(obj,button)
  if button == "LeftButton" then
    addon:ToggleLocked(nil,true)
  elseif button == "RightButton" then
    addon:ToggleOptionsFrame()
  end
end
function addon.OnLDBTooltipShow(tooltip)
  tooltip = tooltip or GameTooltip
  local title = addon._addonNameC
  tooltip:SetText(title)
  local hint = L["|cffff7f00Click|r to toggle lock"]
  tooltip:AddLine(hint)
  hint = L["|cffff7f00Right Click|r to open options"]
  tooltip:AddLine(hint)
end

function addon:PLAYER_REGEN_ENABLED()
  while #(_p.combat_queue)>0 do
    local method = table.remove(_p.combat_queue)
    self[method](self)
  end
  self:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

function addon:UNIT_SPELLCAST_SUCCEEDED(event, ...)
  local unit, castguid, spellId = ...
  if not _p.spell_data[spellId] then return end
  local marker_desc = _G["WORLD_MARKER".._p.spell_data[spellId]]
  local eClass,classID = unit and UnitClassBase(unit)
  local classColor = classColors[eClass]
  local name, name_c = (UnitName(unit))
  if classColor then
    name_c = classColor:WrapTextInColorCode(name)
  else
    name_c = GRAY_FONT_COLOR:WrapTextInColorCode(name)
  end
  local playerLink = GetPlayerLink(name,name_c)
  local msg = string.format("%s > %s",(playerLink or name_c or unit),marker_desc)
  self:Print(msg)
end
_G["BINDING_HEADER_WORLDMARKERSCLASSIC"] = addonName
for i=1,NUM_WORLD_MARKERS do
  _G[string.format("BINDING_NAME_CLICK WorldMarkerClassicBindButton%d:LeftButton",i)] = WHITE_FONT_COLOR:WrapTextInColorCode(L["Place"]).._G["WORLD_MARKER"..i]
  _G[string.format("BINDING_NAME_CLICK WorldMarkerClassicBindButton%d:RightButton",i)] = GRAY_FONT_COLOR:WrapTextInColorCode(L["Clear"]).._G["WORLD_MARKER"..i]
end
_G["BINDING_NAME_CLICK WorldMarkerClassicBindButtonClear:LeftButton"] = WHITE_FONT_COLOR:WrapTextInColorCode(_G.REMOVE_WORLD_MARKERS)
local cycle_rainbow = textRainbow(L["Cycle World Markers"])
_G["BINDING_NAME_CLICK WorldMarkerClassicBindButtonMulti:LeftButton"] = cycle_rainbow

