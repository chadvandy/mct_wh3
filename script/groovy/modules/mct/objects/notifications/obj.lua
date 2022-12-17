--- TODO the individual Notification object


--[[   TODO
    - transient / persistent
    - multiple types, visually
    - immediate / background (ie. forced popup vs. being a notification on the MCT button)
    
]]

---@class MCT.Notification : Class
local defaults = {}

---@class MCT.Notification : Class
---@field __new fun():MCT.Notification
local Notification = GLib.NewClass("Notification", defaults)


--- TODO multiple types being an internal type loader? 
    -- Title/Text
    -- Title/Text/Image?
    -- Text

function Notification:new(key, type, title, text, is_persistent, is_immediate)
    local o = self:__new()
    o:init(key, type, title, text, is_persistent, is_immediate)

    return o
end

function Notification:init(key, type, title, text, is_persistent, is_immediate)
    assert(get_mct():verify_key(self, key))

end

--- TODO populate the notif within the Notification panel
function Notification:populate()

end

--- TODO trigger a free-standing popup
function Notification:popup()

end

return Notification