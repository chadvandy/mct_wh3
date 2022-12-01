local mct = get_mct()
local Registry = mct.registry
local UI_Main = mct.ui

---@class MCT.UI.Notifications
local defaults = {
    ---@type UIC? The currently selected Profile holder.
    selected_holder = nil,

    --- TODO do I need this?
    selected_profile = "",

    ---@type table<string, UIC>
    uics = {},
}

---@class MCT.UI.Notifications : Class
local UI_Notifications = VLib.NewClass("UI_Notifications", defaults)


--- TODO open up the notifications panel
function UI_Notifications:open()

end