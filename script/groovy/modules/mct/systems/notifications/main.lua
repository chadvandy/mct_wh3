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

function NotificationSystem:get_unread_notifications()

end

function NotificationSystem:get_unread_notifications_count()

end

function NotificationSystem:get_notifications()

end

function NotificationSystem:mark_all_as_read()

end

return NotificationSystem