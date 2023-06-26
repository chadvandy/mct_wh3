local mct = get_mct()
local Super = mct:get_notification_class()

---@class MCT.Notification.TitleText
local defaults = {
    -- creation_callback = function(canvas) end,

    _title = "", 
    _long_text = "",
}

---@class MCT.Notification.TitleText : MCT.Notification, Class
---@field __new fun():MCT.Notification.TitleText
local This = Super:extend("TitleText", defaults)

function This:trigger_full_popup()
    -- create a panel using ui/vandy_lib/popups/pretty_popup
    local panel = core:get_or_create_component("mct_notification_panel", "ui/vandy_lib/popups/pretty_popup", core:get_ui_root())
    panel:Resize(500, 600)

    --- TODO resize based on internal content!

    -- get the close button
    local button_close = find_uicomponent(panel, "button_close")
    button_close:SetState("active")
    button_close:SetInteractive(true)

    -- add a listener to destroy the panel when the close button is clicked
    core:add_listener(
        "mct_notification_panel_close",
        "ComponentLClickUp",
        function(context)
            return context.component == button_close:Address()
        end,
        function()
            panel:Destroy()
        end,
        true
    )

    -- create a title component and dock it to 2, and set it to the title of this notification
    -- use ui/vandy_lib/text/paragraph_header
    local title = core:get_or_create_component("mct_notification_title", "ui/vandy_lib/text/paragraph_header", panel)
    title:SetDockingPoint(2)
    title:SetDockOffset(5, 0)
    title:SetStateText(self:get_title())

    -- create a text component and dock it to 8, and set it to the long text of this notification
    -- use ui/vandy_lib/text/paragraph
    local text = core:get_or_create_component("mct_notification_text", "ui/groovy/text/fe_default", panel)
    text:SetDockingPoint(8)
    text:SetDockOffset(0, -20)
    text:SetStateText(self:get_long_text())
end

return This