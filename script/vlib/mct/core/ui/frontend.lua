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

local is_in_campaign = false

core:add_listener(
    "MCT_CampaignNewLeft",
    "FrontendScreenTransition",
    function(context)
        return context.string ~= "campaign_select_new" and is_in_campaign
    end,
    function(context)
        is_in_campaign = false

        local mct_button = get_mct().ui:get_mct_button()
        local parent = UIComponent(mct_button:Parent())
        parent:SetVisible(true)
    end,
    true
)

core:add_listener(
    "MCT_CampaignNew",
    "FrontendScreenTransition",
    function(context)
        return context.string == "campaign_select_new"
    end,
    function(context)
        is_in_campaign = true

        local mct_button = get_mct().ui:get_mct_button()
        local parent = UIComponent(mct_button:Parent())
        parent:SetVisible(false)

        core:get_tm():real_callback(function()
            local right_holder = find_uicomponent("campaign_select_new", "right_holder")
            local settings_holder = find_uicomponent("campaign_select_new", "right_holder", "tab_settings", "settings_holder")
            local tab_mct = UIComponent(right_holder:CreateComponent("tab_mct", "ui/vandy_lib/image"))
            tab_mct:Resize(settings_holder:Width(), settings_holder:Height())
            tab_mct:SetImagePath("ui/skins/default/fe_backgraund_gradient.png", 0)
            tab_mct:SetCurrentStateImageTiled(0, true)
            tab_mct:SetCurrentStateImageMargins(0, 0, 152, 0, 152)

            local p = settings_holder:DockingPoint()
            local x,y = settings_holder:GetDockOffset()
            tab_mct:SetDockingPoint(p)
            tab_mct:SetDockOffset(x, y)


            local button_list = find_uicomponent("campaign_select_new", "side_panel_holder", "button_list")
            local holder = UIComponent(button_list:CreateComponent("mod_settings_holder", "ui/mct/frontend_button"))

            local button = find_uicomponent(holder, "button_mod_settings")
            local highlight_animation = find_uicomponent(button, "highlight_animation")
            highlight_animation:SetVisible(true)

            local custom_tx = find_uicomponent(button, "custom_text")
            custom_tx:SetStateText("Mod Configuration Tool")
            custom_tx:SetVisible(true)
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
        --- TODO hide close button
        get_mct().ui:open_frame(find_uicomponent("campaign_select_new", "right_holder", "tab_mct"))

        local button = UIComponent(context.component)
        local highlight_animation = find_uicomponent(button, "highlight_animation")
        highlight_animation:SetVisible(false)
    end,
    true
)