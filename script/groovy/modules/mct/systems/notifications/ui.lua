---@module Notification System

--- TODO the notifications UI stuff

local mct = get_mct()

---@ignore
---@class UI_Notifications
local defaults = {
    ---@type UIC #The primary button on the docker for this UI.
    _Button = nil,

    ---@type boolean The filter state for show/hide read notifications. False is show all, true is hide read.
    _FilterState = false,
}

---@class UI_Notifications
local UI_Notifications = GLib.NewClass("UI_Notifications", defaults)

function UI_Notifications:init()

end

function UI_Notifications:close_banner()
    -- close the banner holder, by setting it invisible
    local banner_holder = self:get_banner_holder()
    banner_holder:SetVisible(false)

    self._Button:SetState("active")
end

function UI_Notifications:open_banner()
    -- open the banner holder, by setting it visible
    local banner_holder = self:get_banner_holder()
    banner_holder:SetVisible(true)

    self._Button:SetState("selected")
end

--- TODO resize holder based on the number of notifications
--- TODO start as invisible
function UI_Notifications:create_banner_holder(parent)
    --- TODO this should probably be a list engine.
    --- TODO create the banner-holder component for notifications dropping from the MCT button.
    local banner_holder = core:get_or_create_component("banner_holder", "ui/groovy/layouts/listview", core:get_ui_root())
    banner_holder:PropagatePriority(100)
    -- banner_holder:SetDockingPoint(7+9) -- bottom left, external
    -- banner_holder:SetDockOffset(0, 0)

    local x, y = parent:Position()
    banner_holder:MoveTo(x - 10, y + parent:Height() + 10)

    banner_holder:Resize(300, 800, false)

    local title = core:get_or_create_component("title", "ui/vandy_lib/text/paragraph_header", banner_holder)
    title:SetDockingPoint(2)
    title:SetDockOffset(0, 10)
    title:SetStateText("Notifications")

    title:Resize(title:Width(), 30)

    -- use ui/groovy/layouts/vlist as filter_holder, dock it to 1, and add a filter checkbox for read notifications
    local filter_holder = core:get_or_create_component("filter_holder", "ui/groovy/layouts/vlist", banner_holder)
    filter_holder:SetDockingPoint(1)
    filter_holder:SetDockOffset(0, title:Height() + 10)

    -- use ui/templates/checkbox_toggle for the checkbox itself, and then add a label component through ui/groovy/text/fe_default
    local filter_checkbox = core:get_or_create_component("filter_checkbox", "ui/templates/checkbox_toggle", filter_holder)
    filter_checkbox:SetTooltipText("Hide read notifications||Hide any previously read notifications from the list.", true)

    local filter_label = core:get_or_create_component("filter_label", "ui/groovy/text/fe_default", filter_checkbox)
    filter_label:SetDockingPoint(1)
    filter_label:SetDockOffset(filter_checkbox:Width() + 5, 0)
    filter_label:SetStateText("Hide read notifications")
    filter_label:Resize(filter_checkbox:Width() * 4, filter_checkbox:Height() * 1.2)
    -- local w,h = filter_label:TextDimensionsForText(filter_label:GetStateText())
    -- filter_label:ResizeTextResizingComponentToInitialSize(w, h)

    -- use ui/groovy/layouts/hlist as a button_holder, dock it to 3, and add a close button and mark all as read button using the round_small_button template 
    local button_holder = core:get_or_create_component("button_holder", "ui/groovy/layouts/hlist", banner_holder)
    button_holder:SetDockingPoint(3)
    -- it should take into account the height and docking offset of the title! ie. if the title is 10 down and 30 tall, the button holder should at least be down by 40px
    button_holder:SetDockOffset(0, title:Height() + 10)

    local mark_all_read_button = core:get_or_create_component("mark_all_read_button", "ui/templates/round_small_button", button_holder)
    mark_all_read_button:SetDockingPoint(1)
    mark_all_read_button:SetDockOffset(0, 0)
    mark_all_read_button:SetImagePath("ui/skins/default/icon_end_turn_notification_generic.png")
    mark_all_read_button:SetTooltipText("Mark all as read||Mark all notifications as read", true)

    local close_button = core:get_or_create_component("close_button", "ui/templates/round_small_button", button_holder)
    close_button:SetDockingPoint(1)
    close_button:SetDockOffset(0, 0)
    -- hey Copilot: close icon is "icon_cross_square", not "icon_close"
    close_button:SetImagePath("ui/skins/default/icon_cross_square.png")
    close_button:SetTooltipText("Close||Close the notifications panel", true)

    core:add_listener(
        "mct_notifications_close_button_pressed",
        "ComponentLClickUp",
        function(context)
            return context.component == close_button:Address()
        end,
        function(context)
            UI_Notifications:close_banner()
        end,
        true
    )

    core:add_listener(
        "mct_notifications_mark_all_read_button_pressed",
        "ComponentLClickUp",
        function(context)
            return context.component == mark_all_read_button:Address()
        end,
        function(context)
            mct:get_notification_system():mark_all_as_read()
            UI_Notifications:refresh_button()
        end,
        true
    )

    core:add_listener(
        "mct_notifications_filter_checkbox_pressed",
        "ComponentLClickUp",
        function(context)
            return context.component == filter_checkbox:Address()
        end,
        function(context)
            self._FilterState = not self._FilterState
            UI_Notifications:apply_filter()
        end,
        true
    )

    local list_clip = find_uicomponent(banner_holder, "list_clip")
    local list_box = find_uicomponent(list_clip, "list_box")

    list_clip:SetDockingPoint(8)
    list_box:SetDockingPoint(8)

    list_clip:Resize(290, 700, false)
    list_box:Resize(290, 700, false)

    list_box:SetInteractive(false)
    list_clip:SetInteractive(false)

    self._notification_banner = banner_holder

    self:populate_banner()
    self:apply_filter()
    self:close_banner()
end

function UI_Notifications:get_banner_holder()
    return self._notification_banner
end

function UI_Notifications:get_banner_holder_box()
    return find_uicomponent(self._notification_banner, "list_clip", "list_box")
end

function UI_Notifications:apply_filter()
    -- apply filter to the banner holder box, to hide any notifications that are read
    local banner_holder_box = self:get_banner_holder_box()
    local notifications = mct:get_notification_system():get_notifications()

    for i = 1, #notifications do
        local notification = notifications[i]
        local notification_banner = find_uicomponent(banner_holder_box, "notification_banner_"..i)

        if notification:is_read() then
            notification_banner:SetVisible(not self._FilterState)
        end
    end
end

--- create each individual banner for each notification saved in NotificationSystem
function UI_Notifications:populate_banner()
    local banner_holder = self:get_banner_holder_box()
    local notifications = mct:get_notification_system():get_notifications()

    for i = 1, #notifications do
        local notification = notifications[i]
        local notification_banner = core:get_or_create_component("notification_banner_"..i, "ui/groovy/notifications/banner", banner_holder)
    
        --- TODO resize based on the size of the text!
        notification_banner:Resize(banner_holder:Width(), 150)
        --- Set the short text!
        local dy_txt = find_uicomponent(notification_banner, "dy_txt")
        dy_txt:SetStateText(notification:get_short_text())
    
        notification_banner:SetVisible(true)
        notification_banner:TriggerAnimation("show")

        notification_banner:SetProperty("index", i)
    
        --- TODO set up details / mark as read
        
        local button_view_details = find_uicomponent(notification_banner, "button_view_details")
        local button_mark_read = find_uicomponent(notification_banner, "button_mark_read")

        core:remove_listener("notification_"..i.."_button_view_details_pressed")
        core:add_listener(
            "notification_"..i.."_button_view_details_pressed",
            "ComponentLClickUp",
            function(context)
                return context.component == button_view_details:Address()
            end,
            function(context)
                notification:trigger_full_popup()
                notification:mark_as_read()
                UI_Notifications:refresh_button()
            end,
            true
        )

        core:remove_listener("notification_"..i.."_button_mark_read_pressed")
        core:add_listener(
            "notification_"..i.."_button_mark_read_pressed",
            "ComponentLClickUp",
            function(context)
                return context.component == button_mark_read:Address()
            end,
            function(context)
                notification:mark_as_read()
                UI_Notifications:refresh_button()
            end,
            true
        )
    end

    self:resize_panel()
end

function UI_Notifications:create_button(parent, x, y)
    local notifications_button = core:get_or_create_component("button_mct_notifications", "ui/templates/round_small_button_toggle", parent)

    notifications_button:SetImagePath("ui/skins/default/icon_end_turn_notification_generic.png")
    notifications_button:SetTooltipText("Notifications||Review any notifications", true)

    if x and y then
        notifications_button:MoveTo(x, y)
    else
        notifications_button:SetDockingPoint(6)
        notifications_button:SetDockOffset(notifications_button:Width() * -4, 0)
    end

    self._Button = notifications_button

    local label_num = core:get_or_create_component("label_num", "ui/groovy/label_num", notifications_button)
    label_num:SetTooltipText("", true)
    label_num:SetDockOffset(18, 13)
    label_num:SetImageRotation(0, math.rad(90))

    self:refresh_button()
    self:create_banner_holder(notifications_button)

    --- TODO dynamic tooltip w/ different state text
    --- TODO pulse (or something) if there's urgent notifs

    core:add_listener(
        "mct_notifications_button_pressed",
        "ComponentLClickUp",
        function(context)
            return context.component == notifications_button:Address()
        end,
        function(context)
            UI_Notifications:toggle()
        end,
        true
    )

    return notifications_button
end

-- Close if open, open if close, and set the state for the button
function UI_Notifications:toggle()
    local banner_holder = self:get_banner_holder()

    if banner_holder:Visible() then
        self:close_banner()
    else
        self:open_banner()
    end
end

function UI_Notifications:refresh_button()
    local button = self._Button
    local label_num = find_uicomponent(button, "label_num")

    local unread_count = mct:get_notification_system():get_unread_notifications_count()
    label_num:SetStateText(tostring(unread_count))
end


function UI_Notifications:resize_panel()
    local banner_holder = self:get_banner_holder()

    local list_clip = find_uicomponent(banner_holder, "list_clip")
    local list_box = find_uicomponent(list_clip, "list_box")

    local num_children = list_box:ChildCount()
    local height = 0

    for i = 0, num_children - 1 do
        local child = UIComponent(list_box:Find(i))
        height = height + child:Height()
    end

    local ydiff = 100

    local mw, my = 290, 700

    if height > my then
        height = my
    end

    list_clip:Resize(mw, height, false)
    list_box:Resize(mw, height, false)
    banner_holder:Resize(mw, ydiff + height, false)
end

return UI_Notifications
