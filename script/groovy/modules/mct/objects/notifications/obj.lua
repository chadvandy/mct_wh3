---@module Notification System

--- TODO the individual Notification object


--[[   TODO
    - transient / persistent
    - multiple types, visually
    - immediate / background (ie. forced popup vs. being a notification on the MCT button)
    
]]

---@ignore
---@class Notification
local defaults = {
    ---@type boolean Whether this notification will persist after this game session.
    _persistence = false,

    ---@type boolean Whether this notification has been read by the user.
    _is_read = false,

    ---@type string The title for this notification.
    _title = "",

    ---@type string Short text for the banner notification / preview in the notification panel.
    _short_text = "",

    ---@type string Long text for the notification panel.
    _long_text = "",
}

---@class Notification
---@field __new fun():Notification
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
    -- assert(get_mct():verify_key(self, key))

end

--- TODO an overriden populate function that allows us to do custom UI bits for a notification.
--- TODO populate the notif within the Notification panel
function Notification:populate(panel)

end

--- TODO trigger a free-standing popup
function Notification:create_banner_popup()
    local banner_holder = get_mct():get_notification_system():get_ui():get_banner_holder_box()


    get_mct():get_notification_system():get_ui():resize_panel()
end

function Notification:trigger_full_popup()

end

-- set the title text for the notification
function Notification:set_title(title)
    self._title = title

    return self
end

-- get the title text for the notification
function Notification:get_title()
    return self._title
end

-- set the short text for the notification
function Notification:set_short_text(text)
    assert(is_string(text))
    self._short_text = text

    return self
end 

-- get the short text for the notification

function Notification:get_short_text()
    return self._short_text
end

-- set the long text for the notification

function Notification:set_long_text(text)
    assert(is_string(text))
    self._long_text = text

    return self
end

-- get the long text for the notification
function Notification:get_long_text()
    return self._long_text
end


--- a function to mark the notificationa as read or unread
function Notification:mark_as_read(b)
    if is_nil(b) then b = true end
    self._is_read = b
end

-- read if the notification is read or not
function Notification:is_read()
    return self._is_read
end

function Notification:is_persistent()
    return self._persistence
end

function Notification:set_persistent(b)
    self._persistence = b

    return self
end


return Notification
