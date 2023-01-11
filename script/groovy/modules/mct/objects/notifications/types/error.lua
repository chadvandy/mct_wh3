--- TODO a notification type that displays an error code, and a button to copy it to the clipboard, and a button to open the log file, and the option to view further details

local mct = get_mct()
local Super = mct:get_notification()

---@class MCT.Notification.Error
local defaults = {
    -- creation_callback = function(canvas) end,

    _title = "Error!",
    _long_text = "",

    _short_text = "",
    _error_text = "",
}

---@class MCT.Notification.Error : MCT.Notification, Class
---@field __new fun():MCT.Notification.Error
---@field new fun():MCT.Notification.Error
local This = Super:extend("Notification.Error", defaults)

function This:set_error_text(t)
    assert(is_string(t), "Error text must be a string!")
    self._error_text = t

    return self
end

function This:get_error_text()
    return self._error_text
end

function This:trigger_full_popup()
    -- create a panel using ui/vandy_lib/popups/pretty_popup
    local panel = core:get_or_create_component("mct_notification_panel", "ui/vandy_lib/popups/pretty_popup", core:get_ui_root())

    local sw,sh = core:get_screen_resolution()
    panel:Resize(sw * 0.4, sh * 0.65)
    -- panel:SetMoveable(true)

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
    title:SetDockOffset(5, 5)
    title:SetStateText(self:get_title())

    local error_code = core:get_or_create_component("error_code", "ui/groovy/text/fe_italic", panel)
    error_code:SetDockingPoint(2)
    error_code:SetDockOffset(0, title:Height() + 10)
    error_code:SetStateText(self:get_error_text())
    error_code:Resize(panel:Width() * 0.8, panel:Height() * 0.1)
    error_code:SetTextHAlign("centre")

    -- create a text component and dock it to 8, and set it to the long text of this notification
    local textview = core:get_or_create_component("mct_notification_text", "ui/groovy/layouts/textview", panel)
    textview:SetDockingPoint(2)
    textview:SetDockOffset(0, title:Height() +  error_code:Height() + 15)
    textview:SetCanResizeWidth(true)
    textview:SetCanResizeHeight(true)
    textview:Resize(panel:Width() * 0.9, panel:Height() * 0.75)
    textview:SetCanResizeHeight(false)
    textview:SetCanResizeWidth(false)

    local text = find_uicomponent(textview, "text")
    text:SetStateText(self:get_long_text())
    text:SetCanResizeWidth(true)
    text:SetCanResizeHeight(true)
    text:Resize(panel:Width() * 0.9, panel:Height() * 0.75)
    text:SetCanResizeHeight(false)
    text:SetCanResizeWidth(false)
    text:SetTextHAlign("left")

    --  a button to copy the text of the error to the clipboard
    local button_copy = core:get_or_create_component("mct_notification_button_copy", "ui/templates/square_medium_text_button", panel)
    find_uicomponent(button_copy, "button_txt"):SetStateText("Copy to Clipboard")

    button_copy:SetDockingPoint(8)
    button_copy:SetDockOffset(0, -8)
    
    -- listen for button_copy being pressed -> call copy_to_clipboard
    core:add_listener(
        "mct_notification_button_copy",
        "ComponentLClickUp",
        function(context)
            return context.component == button_copy:Address()
        end,
        function()
            local str = string.format("%s\n\n%s", self:get_error_text(), self:get_long_text())
            -- remove [[col:]] tags and [[/col]] tags
            str = string.gsub(str, "%[%[col:%w+%]%]", "")
            str = string.gsub(str, "%[%[/col%]%]", "")

            GLib.CopyToClipboard(str)
        end,
        true
    )

    --- TODO implement this later; save a specified file with the log currently loaded.
    -- -- a button to save the log file
    -- local button_save = core:get_or_create_component("mct_notification_button_save", "ui/templates/square_medium_text_button", panel)
    -- find_uicomponent(button_save, "button_txt"):SetStateText("Save Log File")

    -- button_save:SetDockingPoint(8)
    -- button_save:SetDockOffset(-button_copy:Width() - 5, -5)

    -- -- listen for button_save being pressed -> call save_log_file
    -- core:add_listener(
    --     "mct_notification_button_save",
    --     "ComponentLClickUp",
    --     function(context)
    --         return context.component == button_save:Address()
    --     end,
    --     function()
    --         self:save_log_file()
    --     end,
    --     true
    -- )

end

function This:save_log_file()

end

return This