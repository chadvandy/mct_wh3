--- TODO the systems for the frontend button, the pre-campaign specific menu, etc.

local mct = get_mct()

---@class MCT.UI
local ui = mct.ui


--- UI initalization

local function init()
    local bar = find_uicomponent("sp_frame", "menu_bar")
    local existing = find_uicomponent(bar, "button_tw_academy")

    local x,y = existing:Position()

    local mct_button = get_mct().ui:create_mct_button(bar)
    mct_button:MoveTo(x, y)

    existing:SetVisible(false)
    bar:SetVisible(true)
end

core:add_ui_created_callback(init)