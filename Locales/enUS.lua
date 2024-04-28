local addonName, wmc = ...
local L = LibStub("AceLocale-3.0"):NewLocale(addonName, "enUS", true)
if not L then return end
  --["Term"] = true -- Example
  -- common
L["Hide from Minimap"] = true
L["Button Size"] = true
L["Border Size"] = true
L["Increase Border size temporarily if you're having trouble dragging."] = true
L["Orientation"] = true
L["Notify Marker"] = true
L["Locked"] = true
L["Place"] = true
L["Clear"] = true
L["Unlocked. Drag by edge."] = true
L["Notify a World Marker was placed"] = true
L["Cycle World Markers"] = true
L["|cffffffffClick|r to place"] = true
L["|cffffffffRight-Click|r to remove"] = true
L["|cffff7f00Click|r to toggle lock"] = true
L["|cffff7f00Right Click|r to open options"] = true
L.CMD_LOCK = "Toggle Lock"
L.CMD_RESET = "Reset Position"

wmc.L = L
