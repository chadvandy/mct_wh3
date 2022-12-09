local mct = get_mct()

---@class MCT.UI
local ui = mct:get_ui()

core:add_ui_created_callback(function()
    local p = find_uicomponent("menu_bar", "buttongroup")
    local mct_button = get_mct():get_ui():create_mct_button(p)
end)