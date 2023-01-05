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
function Notification:populate(panel)

end

--- TODO trigger a free-standing popup
function Notification:trigger_banner_popup()
    local banner_holder = get_mct():get_notification_system():get_ui():get_banner_holder_box()
    local banner = core:get_or_create_component("mct_notification_banner", "ui/groovy/notifications/banner", banner_holder)
    
    --- TODO resize based on the size of the text!
    banner:Resize(banner_holder:Width(), 150)
    --- Set the short text!
    local dy_txt = find_uicomponent(banner, "dy_txt")
    dy_txt:SetStateText(self:get_short_text())

    banner:SetVisible(true)
    banner:TriggerAnimation("show")

    --- TODO set up details / mark as read
    
    local button_view_details = find_uicomponent(banner, "button_view_details")
    local button_mark_read = find_uicomponent(banner, "button_mark_read")

    -- -- view details callback and listener
    -- local callback_view_details = function()
    --     local panel = get_mct():get_ui()
    --     local panel_holder = find_uicomponent(panel, "panel_holder")
    --     local panel_content = find_uicomponent(panel_holder, "panel_content")

    --     -- populate the panel with the notification details
    --     self:populate(panel)

    --     -- hide the banner
    --     banner:SetVisible(false)
    --     banner:Destroy()

    --     -- show the panel
    --     panel:SetVisible(true)
    --     panel:TriggerAnimation("show")
    -- end
end

function Notification:trigger_full_popup()
    --- Trigger the full popup for the Notification, using ui/mct/frame as the component path, with core:get_ui_root() as the parent, and applying the title and long text to the frame with a close button.
    local frame = core:get_or_create_component("mct_notification_frame", "ui/mct/frame", core:get_ui_root())
    frame:Resize(300, 200)


    

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