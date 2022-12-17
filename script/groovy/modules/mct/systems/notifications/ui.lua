--- TODO the notifications UI stuff

local mct = get_mct()
local Registry = mct:get_registry()
local UI_Main = mct:get_ui()

---@class MCT.UI.Notifications
local defaults = {

}

---@class MCT.UI.Notifications : Class
local UI_Notifications = GLib.NewClass("UI_Notifications", defaults)


--- TODO open up the notifications panel
function UI_Notifications:open()

end

return UI_Notifications