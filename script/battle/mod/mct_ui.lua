--- TODO add MCT to the Esc menu

--- Battle scripts are triggered after UI is already created
core:get_tm():repeat_real_callback(function()
    local p = find_uicomponent("menu_bar", "buttongroup")

    if is_uicomponent(p) then
        core:get_tm():remove_real_callback("mct_button_test")

        local mct_button = get_mct().ui:create_mct_button(p)
        get_mct().ui:ui_created()
    end
end, 100, "mct_button_test")