--- TODO a notification type that displays an error code, and a button to copy it to the clipboard, and a button to open the log file, and the option to view further details

local mct = get_mct()
local Super = mct:get_notification()

---@class MCT.Notification.Error
local defaults = {
    -- creation_callback = function(canvas) end,

    _title = "", 
    _long_text = "",
}

---@class MCT.Notification.Error : MCT.Notification, Class
---@field __new fun():MCT.Notification.Error
local This = Super:extend("Notification.Error", defaults)

