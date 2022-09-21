local function resize_scrap_panel()

local docker_component = find_uicomponent(core:get_ui_root(), "units_panel", "main_units_panel", "scrap_upgrades_docker", "scrap_upgrades", "scrap_upgrades_list_box");
local top_box = find_uicomponent(docker_component, "scrap_upgrades_parent")
local bottom_box = find_uicomponent(top_box, "list_clip", "list_box")

local vslider = core:get_or_create_component("vslider", "ui/templates/parchment_slider_vertical", top_box)

-- local new_view = UIComponent(docker_component:CreateComponent("scrap_upgrades_parent", "test"))
-- new_view:Resize(top_box:Width() - 5, top_box:Height())
-- new_view:SetDockingPoint(top_box:DockingPoint())
-- local x,y = top_box:GetDockOffset()
-- new_view:SetDockOffset(x, y)

-- local new_box = find_uicomponent(new_view, "list_clip", "list_box")

-- for i = bottom_box:ChildCount() -1, 0, -1 do
--     local child = UIComponent(bottom_box:Find(i))
--     new_box:Adopt(child:Address())
-- end

-- top_box:Destroy()
-- new_view:SetVisible(true)
-- -- top_box:Destroy()

end



local function add_scrap_upgrade_listeners()
    core:add_listener(
        "Scrap_Panel_Resize_Init",
        "PanelOpenedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            core:add_listener(
                "Scrap_Panel_Resize",
                "ComponentLClickUp",
                function(context) 
                    return context.string == "button_upgrade" and cm:get_local_faction_subculture(true) == "wh2_dlc09_sc_tmb_tomb_kings"
                end,
                function(context)
                    core:get_tm():real_callback(resize_scrap_panel, 1)
                end,
                false
            )
        end,
        true
    )

    core:add_listener(
        "Scrap_Panel_Resize_End",
        "PanelClosedCampaign",
        function(context)
            return context.string == "units_panel"
        end,
        function(context)
            core:remove_listener("Scrap_Panel_Resize")
        end,
        true
    )
end;

cm:add_first_tick_callback(add_scrap_upgrade_listeners) 
