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
---@param notif MCT.Notification
---@return MCT.Notification
function NotificationSystem:save_notification(notif)
    --- TODO save it internally? Do what?

    self._notifications[#self._notifications+1] = notif

    return notif
end

--- TODO pass forward anything special?
function NotificationSystem:create_title_and_text_notification()
    local Notification = get_mct():get_notification_class_subtype("title_and_text")
    ---@cast Notification MCT.Notification.TitleText

    local o = Notification:new()
    self:save_notification(o)

    return o
end

---@return MCT.Notification.Error
function NotificationSystem:create_error_notification()
    local Notification = get_mct():get_notification_class_subtype("error")
    ---@cast Notification MCT.Notification.Error

    local o = Notification:new()
    self:save_notification(o)

    return o
end

function NotificationSystem:create_banner_notification()

end

--- Get all unread notifications.
---@return MCT.Notification[]
function NotificationSystem:get_unread_notifications()
    local unread = {}
    for i,notification in ipairs(self:get_notifications()) do 
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
    for i,notification in ipairs(self:get_notifications()) do
        notification:mark_as_read()
    end
end

function NotificationSystem:get_ui()
    return self._UI
end

return NotificationSystem