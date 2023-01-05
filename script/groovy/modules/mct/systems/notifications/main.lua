--- TODO the full notifications system

---@class MCT.NotificationSystem : Class
local defaults = {
    --- All saved / unread notifications.
    ---@type MCT.Notification[]
    _notifications = {},

    ---@type MCT.UI.Notifications
    _UI = nil,
}

---@class MCT.NotificationSystem : Class
local NotificationSystem = GLib.NewClass("MCT.NotificationSystem", defaults)



function NotificationSystem:init()
    self._UI = GLib.LoadModule("ui", get_mct():get_path("systems", "notifications"))
end

--- TODO
function NotificationSystem:load()

end

function NotificationSystem:save()

end

--- Simply create a new notification and return it to the caller.
---@return MCT.Notification
function NotificationSystem:create_notification()
    ---@type MCT.Notification
    local Notification = get_mct():get_notification()
    local o = Notification:new()

    --- TODO save it internally? Do what?

    return o
end


function NotificationSystem:create_banner_notification()

end

--- Get all unread notifications.
---@return MCT.Notification[]
function NotificationSystem:get_unread_notifications()
    local unread = {}
    for i,notification in pairs(self:get_notifications()) do 
        if not notification:is_read() then
            table.insert(unread, notification)
        end
    end

    return unread
end

--- Get the number of unread notifications.
---@return number
function NotificationSystem:get_unread_notifications_count()
    return #self:get_unread_notifications()
end

---@return MCT.Notification[] #Get all saved and tracked notifications
function NotificationSystem:get_notifications()
    return self._notifications
end

function NotificationSystem:mark_all_as_read()

end

function NotificationSystem:get_ui()
    return self._UI
end

return NotificationSystem