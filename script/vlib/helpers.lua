--- Testing testing
---@param text string
---@return string
function vlib_format_text(text)
    if not is_string(text) then
        return ""
    end

    -- check for wrapped {{loc:loc_key}} text. If there's any, automatically replace it with the localised string.
    local x,start = text:find("{{loc:")
    if x then
        local close,y = text:find("}}", start+1)
        if close then
            local loc_key = text:sub(start+1, close-1)

            local loc_text = common.get_localised_string(loc_key)
            
            return table.concat({text:sub(1, x-1), loc_text, text:sub(y+1, -1)})
        end
    end

    return text
end

--- Weird name. Takes a string, and add "ui/skins/default/" and ".png" to the front and back of it. That way, you can supply `skin_image("icon_plus") and get "ui/skins/default/icon_plus.png"
---@param t string
---@return string
function skin_image(t)
    if not is_string(t) then return "ui/skins/default/icon_wh_main_lore_vampire.png" end
    local pre = "ui/skins/default/"
    local post = ".png"

    if t:match(".png$") then
        post = ""
    end

    vlogf("Skinning image %s into %s", t, pre .. t .. post)

    return pre .. t .. post
end

function vlib_trigger_popup(key, text, two_buttons, button_one_callback, button_two_callback, opt_parent)
    -- verify shit is alright
    if not is_string(key) then
        verr("trigger_popup() called, but the key passed is not a string!")
        return false
    end

    if is_function(text) then
        text = text()
    end

    if not is_string(text) then
        verr("trigger_popup() called, but the text passed is not a string!")
        return false
    end

    if is_function(two_buttons) then
        two_buttons = two_buttons()
    end

    if not is_boolean(two_buttons) then
        verr("trigger_popup() called, but the two_buttons arg passed is not a boolean!")
        return false
    end

    local parent = is_uicomponent(opt_parent) and opt_parent or core:get_ui_root()

    if not two_buttons then button_two_callback = function() end end

    local popup = core:get_or_create_component(key, "ui/vandy_lib/dialogue_box", parent)

    local function do_stuff()

        local both_group = UIComponent(popup:CreateComponent("both_group", "ui/campaign ui/script_dummy"))
        local ok_group = UIComponent(popup:CreateComponent("ok_group", "ui/campaign ui/script_dummy"))
        local DY_text = UIComponent(popup:CreateComponent("DY_text", "ui/vandy_lib/text/la_gioconda/center"))

        both_group:SetDockingPoint(8)
        both_group:SetDockOffset(0, 0)

        ok_group:SetDockingPoint(8)
        ok_group:SetDockOffset(0, 0)

        DY_text:SetDockingPoint(5)
        -- errlog("WHAT THE FUCK IS CALLING THIS")
        local ow, oh = popup:Width() * 0.9, popup:Height() * 0.8
        DY_text:Resize(ow, oh)
        DY_text:SetDockOffset(1, -35)
        DY_text:SetVisible(true)

        local cancel_img = skin_image("icon_cross.png")
        local tick_img = skin_image("icon_check.png")

        do
            local button_tick = UIComponent(both_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))
            local button_cancel = UIComponent(both_group:CreateComponent("button_cancel", "ui/templates/round_medium_button"))

            button_tick:SetImagePath(tick_img)
            button_tick:SetDockingPoint(8)
            button_tick:SetDockOffset(-30, -10)
            button_tick:SetCanResizeWidth(false)
            button_tick:SetCanResizeHeight(false)
            button_tick:SetTooltipText(common.get_localised_string("vlib_popup_confirm"), true)
            
            button_cancel:SetImagePath(cancel_img)
            button_cancel:SetDockingPoint(8)
            button_cancel:SetDockOffset(30, -10)
            button_cancel:SetCanResizeWidth(false)
            button_cancel:SetCanResizeHeight(false)
            button_cancel:SetTooltipText(common.get_localised_string("vlib_popup_cancel"), true)
        end

        do
            local button_tick = UIComponent(ok_group:CreateComponent("button_tick", "ui/templates/round_medium_button"))

            button_tick:SetImagePath(tick_img)
            button_tick:SetDockingPoint(8)
            button_tick:SetDockOffset(0, -10)
            button_tick:SetCanResizeWidth(false)
            button_tick:SetCanResizeHeight(false)
        end

        popup:PropagatePriority(1000)

        popup:LockPriority()

        -- grey out the rest of the world
        --popup:RegisterTopMost()

        if two_buttons then
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

        core:add_listener(
            key.."_button_pressed",
            "ComponentLClickUp",
            function(context)
                local button = UIComponent(context.component)
                return (button:Id() == "button_tick" or button:Id() == "button_cancel") and UIComponent(UIComponent(button:Parent()):Parent()):Id() == key
            end,
            function(context)
                -- close the popup
				local ok, er = pcall(function() delete_component(popup) end) if not ok then verr(er) end
                delete_component(find_uicomponent(key))

                if context.string == "button_tick" then
                    vlogf("Calling button one callback for %s", key)
                    button_one_callback()
                    vlogf("Calling button one callback for %s end", key)
                else
                    vlogf("Calling button two callback for %s", key)
                    button_two_callback()
                    vlogf("Calling button two callback for %s end", key)
                end
            end,
            false
        )
    end

    core:get_tm():real_callback(do_stuff, 5, "do_stuff")
end