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

local function handle_sp()
    local uic_path = "ui/templates/square_medium_text_tab"
    local parent = find_uicomponent("campaign_select_new", "side_panel_holder", "button_list")

    local existing_holder = find_uicomponent(parent, "game_settings_holder")
    local existing_button = find_uicomponent(existing_holder, "button_game_settings")

    local mct_holder = core:get_or_create_component("mct_settings_holder", "ui/campaign ui/script_dummy", parent)
    mct_holder:Resize(existing_holder:Height(), existing_holder:Width())

    local mct_button = core:get_or_create_component("button_mct", "ui/templates/fe_square_button", mct_holder)
    find_uicomponent(mct_button, "button_txt"):SetStateText("MOD CONFIGURATION")

    parent:Layout()
end

--- root > mp_grand_campaign > ready_parent > tab_buttons > button_tab_settings
local function handle_mp()
    local uic_path = "ui/templates/fe_square_large_text_tab_toggle"
    local path = find_uicomponent("mp_grand_campaign", "ready_parent", "tab_buttons")
    local button = core:get_or_create_component("button_mct", uic_path, path)

    local text = core:get_or_create_component("title", "ui/vandy_lib/text/paragraph_header", button)
    text:SetDockingPoint(5)
    text:SetTextHAlign('centre')
    text:SetTextVAlign('centre')
    text:SetTextYOffset(0, 0)
    text:SetTextXOffset(0, 0)

    text:SetStateText("Mod Settings")
    text:SetInteractive(false)
end

--- TODO setup custom battle shit
local function handle_cb()
    local parent = find_uicomponent("custom_battle", "ready_parent", "tab_buttons")
end

core:add_listener(
    "MctFrontend",
    "FrontendScreenTransition",
    true,
    function(context)
        local s = context.string
        core:get_tm():real_callback(function()
            if s == "campaign_select_new" then
                handle_sp()
            elseif s == "mp_grand_campaign" then
                handle_mp()
            elseif s == "custom_battle" then
                handle_cb()
            elseif s == "quest_battles" then
                --- TODO necessary?
                -- handle_qb()
            end
        end, 10)
    end,
    true
)