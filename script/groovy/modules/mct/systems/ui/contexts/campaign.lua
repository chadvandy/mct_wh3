---@module MCT UI

local mct = get_mct()

---@ignore
---@class UI_Main
local ui = mct:get_ui()

---@class UI_Campaign
local UI_Campaign = {}

function UI_Campaign:init()
    core:add_ui_created_callback(function()
        self:ui_created()
    end)
end

function UI_Campaign:ui_created()
    local p = find_uicomponent("menu_bar", "buttongroup")
    -- local mct_button = get_mct():get_ui():create_mct_button(p)
    get_mct():create_main_holder(p)
    get_mct():get_ui():ui_created()
end

return UI_Campaign
