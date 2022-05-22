--- TODO add MCT to the Esc menu

-- core:add_listener(
--     "MCT_EscMenu",
--     "PanelOpenedCampaign",
--     function(context)
--         return context.string == "esc_menu"
--     end,
--     function(context)
--         --- TODO add the button where it go
--         local holder = find_uicomponent("esc_menu", "main", "menu_left", "frame_options")
--         local exists = find_uicomponent(holder, "button_mct")
--         if is_uicomponent(exists) then
--             return
--         end

--         local other = find_uicomponent(holder, "button_audio")
--         local w,h = other:Dimensions()
--         local mct = core:get_or_create_component("button_mct", "ui/templates/fe_small_square_button", holder)
--         mct:SetCanResizeHeight(true)
--         mct:SetCanResizeWidth(true)
--         mct:Resize(w, h)
--         --- TODO text/tooltip/img
--     end,
--     true
-- )

--- UI initalization
core:add_listener(
    "MctButton",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct"
    end,
    function(context)
        core:get_tm():real_callback(function()
            get_mct():open_panel()
        end, 5, "mct_button")
    end,
    true
)

core:add_ui_created_callback(function()
    local p = find_uicomponent("menu_bar", "buttongroup")
    local mct_button = core:get_or_create_component("button_mct", "ui/templates/round_small_button", p)
end)