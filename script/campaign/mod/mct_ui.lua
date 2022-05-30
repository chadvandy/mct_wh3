core:add_ui_created_callback(function()
    local p = find_uicomponent("menu_bar", "buttongroup")
    local mct_button = get_mct().ui:create_mct_button(p)
end)