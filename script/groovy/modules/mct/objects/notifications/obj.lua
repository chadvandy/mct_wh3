--- TODO the individual Notification object


--[[   TODO
    - transient / persistent
    - multiple types, visually
    - immediate / background (ie. forced popup vs. being a notification on the MCT button)
    
]]

---@class MCT.Notification : Class
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
    -- assert(get_mct():verify_key(self, key))

end

--- TODO an overriden populate function that allows us to do custom UI bits for a notification.
--- TODO populate the notif within the Notification panel
function Notification:populate()

end

--- TODO trigger a free-standing popup
function Notification:popup()
    local banner_holder = get_mct():get_ui()._notification_banner
    local banner = core:get_or_create_component("mct_notification_banner", "ui/groovy/notifications/banner", banner_holder)
    banner:Resize(300, 200)

    --- Set the short text!
    local dy_txt = find_uicomponent(banner, "dy_txt")
    dy_txt:SetStateText(self:get_short_text())

    banner:SetVisible(true)
    banner:TriggerAnimation("show")

    --- TODO listen for the close button being clicked, and mark the notification as read.
    local button_close = find_uicomponent(banner, "button_close")

    local callback = function()
        self:mark_as_read(true)
        -- banner:SetVisible(false)
        banner:Destroy()
    end

    core:add_listener(
        "mct_notification_banner_close",
        "ComponentLClickUp",
        function(context)
            return context.string == button_close:Id()
        end,
        function(context)
            callback()
        end,
        true
    )
end

function Notification:display()

end

-- set the title text for the notification
function Notification:set_title(title)
    self._title = title
end

-- get the title text for the notification
function Notification:get_title()
    return self._title
end

-- set the short text for the notification
function Notification:set_short_text(text)
    assert(is_string(text))
    self._short_text = text
end 

-- get the short text for the notification

function Notification:get_short_text()
    return self._short_text
end

-- set the long text for the notification

function Notification:set_long_text(text)
    assert(is_string(text))
    self._long_text = text
end

-- get the long text for the notification
function Notification:get_long_text()
    return self._long_text
end


--- a function to mark the notificationa as read or unread
function Notification:mark_as_read(b)
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
end


return Notification