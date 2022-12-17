local mct = get_mct()

---@class MCT.UI
local ui = mct:get_ui()

local UI_Battle = {}

function UI_Battle:init()
    --- Battle scripts are triggered after UI is already created
    core:get_tm():repeat_real_callback(function()
        local p = find_uicomponent("menu_bar", "buttongroup")
    
        if is_uicomponent(p) then
            core:get_tm():remove_real_callback("mct_button_test")
    
            self:ui_created(p)
        end
    end, 100, "mct_button_test")
end

function UI_Battle:ui_created(parent)
    local mct_button = get_mct():get_ui():create_mct_button(parent)
    get_mct():get_ui():ui_created()
end

return UI_Battle