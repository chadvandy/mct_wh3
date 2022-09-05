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

core:add_listener(
    "MCT_CampaignNew",
    "FrontendScreenTransition",
    function(context)
        return context.string == "campaign_select_new"
    end,
    function(context)
        core:get_tm():real_callback(function()
            local right_holder = find_uicomponent("campaign_select_new", "right_holder")
            local settings_holder = find_uicomponent("campaign_select_new", "right_holder", "tab_settings", "settings_holder")
            local tab_mct = UIComponent(right_holder:CreateComponent("tab_mct", "ui/templates/panel_frame"))
            tab_mct:Resize(settings_holder:Width(), settings_holder:Height())

            local x,y = settings_holder:Position()
            tab_mct:MoveTo(x, y)

            local button_list = find_uicomponent("campaign_select_new", "side_panel_holder", "button_list")
            button_list:CreateComponent("mod_settings_holder", "ui/mct/frontend_button")
        end, 50)
    end,
    true
)

core:add_listener(
    "MCT_ModSettingsOpened",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mod_settings"
    end,
    function(context)
        get_mct().ui:open_frame(find_uicomponent("campaign_select_new", "right_holder", "tab_mct"))
    end,
    true
)