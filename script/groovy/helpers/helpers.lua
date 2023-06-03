---@ignoreFile
--- I've set this file to be ignored since it add methods to a class that is not defined in this file.
--- LuaAutoDoc currently requires all class methods to be defined in the same file as the class itself.

--- TODO handle the formatted auto-names, ie. `mct_mod_[key]_description
--- Function to handle an optionally localised string.
---@param str string The tested string.
---@param default string? A default to pass if the string is empty and isn't a key.
---@param auto string? The auto-formatted string.
---@return string
function GLib.HandleLocalisedText(str, default, auto)
    if not is_string(str) then return "" end

    -- Test auto first
    auto = common.get_localised_string(auto)
    if is_string(auto) and auto ~= "" then return auto end

    -- Test for a loc syntax in the string
    local catch = str:match("{{loc:(.-)}}")
    if catch then
        -- TODO this needs to be handled better, by swapping each {{loc:}} with the localised text if there's multiple, etc.
        return common.get_localised_string(catch)
    end

    -- Prioritize the provided string.
    if str ~= "" then
        -- if the tested string cannot be localised and isn't empty and isn't a loc key (ie., doesn't have any underscores), then return it.
        local test = common.get_localised_string(str)
        if test ~= "" then
            return test
        else
            return str
        end
    end

    return default
end

--- Weird name. Takes a string, and add "ui/skins/default/" and ".png" to the front and back of it. That way, you can supply `skin_image("icon_plus") and get "ui/skins/default/icon_plus.png"
---@param t string
---@return string
function GLib.SkinImage(t)
    if not is_string(t) then return "ui/skins/default/icon_wh_main_lore_vampire.png" end
    local pre = "ui/skins/default/"
    local post = ".png"

    if t:match(".png$") then
        post = ""
    end

    vlogf("Skinning image %s into %s", t, pre .. t .. post)

    return pre .. t .. post
end

--- TODO change trigger popup and add support for more complicated bullshit like the MCT destruction.
--- TODO auto resize based on contents, optionally resize dynamically
--- TODO return the popup component to do stuff later
--- TODO add in a title component

--- Trigger a popup on the screen, using the Dialogue Box. This wrapper is provided to make handling the whole system a bit easier.
---@param popup_key string
---@param text string
---@param use_two_buttons boolean
---@param button_one_callback function?
---@param button_two_callback function?
---@param creation_callback fun(popup:UIC)?
---@param opt_parent UIC?
function GLib.TriggerPopup(popup_key, text, use_two_buttons, button_one_callback, button_two_callback, creation_callback, opt_parent)
    -- verify shit is alright
    if not is_string(popup_key) then
        GLib.Error("trigger_popup() called, but the key passed is not a string!")
        return false
    end

    if is_function(text) then
        text = text()
    end

    if not is_string(text) then
        GLib.Error("trigger_popup() called, but the text passed is not a string!")
        return false
    end

    if is_function(use_two_buttons) then
        use_two_buttons = use_two_buttons()
    end

    if not is_boolean(use_two_buttons) then
        GLib.Error("trigger_popup() called, but the two_buttons arg passed is not a boolean!")
        return false
    end

    local parent = is_uicomponent(opt_parent) and opt_parent or core:get_ui_root()

    if not is_function(button_one_callback) then button_one_callback = function() end end
    if not is_function(button_two_callback) then button_two_callback = function() end end
    if not use_two_buttons then button_two_callback = function() end end

    local popup = core:get_or_create_component(popup_key, "ui/vandy_lib/dialogue_box", parent)

    core:get_tm():real_callback(function()
        local both_group = find_uicomponent(popup, "both_group")
        local ok_group = find_uicomponent(popup, "ok_group")
        local DY_text = find_uicomponent(popup, "DY_text")

        both_group:SetDockingPoint(8)
        both_group:SetDockOffset(0, 0)

        ok_group:SetDockingPoint(8)
        ok_group:SetDockOffset(0, 0)

        DY_text:SetDockingPoint(5)

        local ow, oh = popup:Width() * 0.9, popup:Height() * 0.8
        DY_text:Resize(ow, oh)
        DY_text:SetDockOffset(1, -35)
        DY_text:SetVisible(true)

        -- local cancel_img = skin_image("icon_cross.png")
        -- local tick_img = skin_image("icon_check.png")

        -- do
        --     -- local button_tick = UIComponent(both_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))
        --     -- local button_cancel = UIComponent(both_group:CreateComponent("button_cancel", "ui/templates/round_medium_button"))

        --     button_tick:SetImagePath(tick_img)
        --     button_tick:SetDockingPoint(8)
        --     button_tick:SetDockOffset(-30, -10)
        --     button_tick:SetCanResizeWidth(false)
        --     button_tick:SetCanResizeHeight(false)
        --     button_tick:SetTooltipText(common.get_localised_string("vlib_popup_confirm"), true)
            
        --     button_cancel:SetImagePath(cancel_img)
        --     button_cancel:SetDockingPoint(8)
        --     button_cancel:SetDockOffset(30, -10)
        --     button_cancel:SetCanResizeWidth(false)
        --     button_cancel:SetCanResizeHeight(false)
        --     button_cancel:SetTooltipText(common.get_localised_string("vlib_popup_cancel"), true)
        -- end

        -- do
        --     local button_tick = UIComponent(ok_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))

        --     button_tick:SetImagePath(tick_img)
        --     button_tick:SetDockingPoint(8)
        --     button_tick:SetDockOffset(0, -10)
        --     button_tick:SetCanResizeWidth(false)
        --     button_tick:SetCanResizeHeight(false)
        -- end

        popup:PropagatePriority(1000)

        popup:LockPriority()

        -- grey out the rest of the world
        --popup:RegisterTopMost()

        if use_two_buttons then
            both_group:SetVisible(true)
            ok_group:SetVisible(false)
        else
            both_group:SetVisible(false)
            ok_group:SetVisible(true)
        end

        -- grab and set the text
        local tx = find_uicomponent(popup, "DY_text")

        local w,h = tx:TextDimensionsForText(text)
        tx:ResizeTextResizingComponentToInitialSize(w,h)

        tx:SetStateText(text)

        tx:Resize(ow,oh)
        --w,h = tx:TextDimensionsForText(text)
        tx:ResizeTextResizingComponentToInitialSize(ow,oh)

        if is_function(creation_callback) then
            creation_callback(popup)
        end

        core:add_listener(
            popup_key.."_button_pressed",
            "ComponentLClickUp",
            function(context)
                local button = UIComponent(context.component)
                return (button:Id() == "button_tick" or button:Id() == "button_cancel") and UIComponent(UIComponent(button:Parent()):Parent()):Id() == popup_key
            end,
            function(context)
                -- close the popup
				local ok, er = pcall(function() 
                    delete_component(popup)

                    if context.string == "button_tick" then
                        -- vlogf("Calling button one callback for %s", popup_key)
                        button_one_callback()
                        -- vlogf("Calling button one callback for %s end", popup_key)
                    else
                        -- vlogf("Calling button two callback for %s", popup_key)
                        button_two_callback()
                        -- vlogf("Calling button two callback for %s end", popup_key)
                    end

                end) if not ok then verr(er) end
            end,
            false
        )
    end, 0, "do_stuff")

    return popup
end
