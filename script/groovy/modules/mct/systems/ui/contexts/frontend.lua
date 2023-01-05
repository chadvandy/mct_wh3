--- TODO the systems for the frontend button, the pre-campaign specific menu, etc.

local mct = get_mct()

---@class MCT.UI
local ui = mct:get_ui()

local UI_Frontend = {}

function UI_Frontend:init()
    core:add_ui_created_callback(function()
        self:ui_created()
    end)
end

function UI_Frontend:ui_created()
    local bar = find_uicomponent("sp_frame", "menu_bar")
    local existing = find_uicomponent(bar, "button_tw_academy")

    -- local x,y = existing:Position()

    -- local mct_button = get_mct():get_ui():create_mct_button(bar)
    -- mct_button:MoveTo(x, y)

    get_mct():create_main_holder(bar)

    existing:SetVisible(false)
    bar:SetVisible(true)

    get_mct():get_sync():new_frontend()
end

function UI_Frontend:listeners()
    local is_in_campaign = false

    core:add_listener(
        "MCT_CampaignNewLeft",
        "FrontendScreenTransition",
        function(context)
            return context.string ~= "campaign_select_new" and is_in_campaign
        end,
        function(context)
            is_in_campaign = false
    
            local mct_button = get_mct():get_ui():get_mct_button()
            local parent = UIComponent(mct_button:Parent())
            parent:SetVisible(true)
    
            core:remove_listener("MCT_ModSettingsClosed")
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
    
            local mct_button = get_mct():get_ui():get_mct_button()
            local parent = UIComponent(mct_button:Parent())
            parent:SetVisible(false)
    
            core:get_tm():real_callback(function()
                local right_holder = find_uicomponent("campaign_select_new", "right_holder")
                local tab_settings = find_uicomponent(right_holder, "tab_settings")
                local settings_holder = find_uicomponent("campaign_select_new", "right_holder", "tab_settings", "settings_holder")
                local bg = find_uicomponent(settings_holder, "background_gradient")
    
                local tab_mct = core:get_or_create_component("tab_mct", "ui/mct/frontend_frame", right_holder)
                tab_mct:Resize(tab_settings:Width(), tab_settings:Height())
                local mct_holder = core:get_or_create_component("mct_holder", "ui/campaign ui/script_dummy", tab_mct)
                mct_holder:Resize(settings_holder:Width(), settings_holder:Height())
    
                tab_mct:SetVisible(false)
    
                local p = settings_holder:DockingPoint()
                local x,y = settings_holder:GetDockOffset()
                mct_holder:SetDockingPoint(p)
                mct_holder:SetDockOffset(x, y)
    
    
                local button_list = find_uicomponent("campaign_select_new", "side_panel_holder", "button_list")
                local holder = UIComponent(button_list:CreateComponent("mod_settings_holder", "ui/mct/frontend_button"))
    
                local button = find_uicomponent(holder, "button_mod_settings")
                -- local highlight_animation = find_uicomponent(button, "highlight_animation")
                -- highlight_animation:SetVisible(true)
    
                local custom_tx = find_uicomponent(button, "custom_text")
                -- custom_tx:SetStateText("Mod Configuration Tool")
                custom_tx:SetVisible(true)
    
                find_uicomponent(tab_mct, "background_gradient"):Resize(bg:Width(), bg:Height())
    
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
            local frame = find_uicomponent("campaign_select_new", "right_holder", "tab_mct", "mct_holder")
            get_mct():get_ui():open_frame(frame, true)
            local close_button = find_uicomponent(frame, "button_mct_close")
            close_button:SetVisible(false)
    
            local button = UIComponent(context.component)
            local highlight_animation = find_uicomponent(button, "highlight_animation")
            highlight_animation:SetVisible(false)
    
            core:add_listener(
                "MCT_ModSettingsClosed",
                "ComponentLClickUp",
                function(i_context)
                    GLib.Log("MCT_ModSettingsClosed conditional: " ..  context.string)
                    local id = i_context.string
                    local uic = UIComponent(i_context.component)
                    return id == "button_start_campaign" or id == "main_tab" or uicomponent_descended_from(uic, "button_list")
                end,
                function()
                    GLib.Log("MCT_ModSettingsClosed callback: " ..  context.string)
                    mct:finalize()
                end,
                false
            )
        end,
        true
    )
end

return UI_Frontend