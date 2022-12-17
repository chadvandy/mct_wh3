--- TODO the full notifications system

---@class MCT.NotificationSystem : Class
local defaults = {
    --- All saved / unread notifications.
    ---@type MCT.Notification[]
    _notifications = {},
}

---@class MCT.NotificationSystem : Class
local NotificationSystem = GLib.NewClass("MCT.NotificationSystem", defaults)

function NotificationSystem:init()

end

--- TODO
function NotificationSystem:load()

end

function NotificationSystem:save()

end

--- TODO
function NotificationSystem:create_notification()

end

function NotificationSystem:get_unread_notifications()

end

function NotificationSystem:get_unread_notifications_count()

end

return NotificationSystem