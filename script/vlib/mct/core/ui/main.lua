---- MCT UI Object. INTERNAL USE ONLY.

-- TODO differentiate betterly between "vlib_ui" which is general UI stuff, and "mct_ui" which is stuff specific to, welp.
-- TODO cleanup crew.
--- TODO move into /core/ 

---@class MCT.UI
local ui_obj = {
    -- UICs --

    -- the MCT button
    mct_button = nil,

    -- script dummy
    dummy = nil,

    -- full panel
    panel = nil,

    -- left side UICs
    mod_row_list_view = nil,
    mod_row_list_box = nil,

    -- right bottom UICs
    mod_settings_panel = nil,

    -- currently selected mod UIC
    selected_mod_row = nil,

    game_ui_created = false,

    ui_created_callbacks = {},

    -- stashed popups, stored within this table, enjoy.
    stashed_popups = {},

    -- if the panel is openeded or closededed
    opened = false,
    notify_num = 0,
}

local mct = get_mct()


local Registry = mct.registry

local log,logf,logerr,logerrf = get_vlog("[mct_ui]")

function ui_obj:get_mct_button()
    return self.mct_button
end

function ui_obj:is_open()
    return self.opened
end

function ui_obj:set_mct_button(uic)
    if not is_uicomponent(uic) then
        -- errmsg
        return false
    end

    self.mct_button = uic

    --- TODO reinstate
    -- -- after getting the button, create the label counter, and then set it invisible
    -- local label = core:get_or_create_component("label_notify", "ui/vandy_lib/number_label", uic)

    -- label:SetStateText("0")
    -- label:SetTooltipText("Notifications", true)
    -- label:SetDockingPoint(3)
    -- label:SetDockOffset(5, -5)
    -- label:SetCanResizeWidth(true) label:SetCanResizeHeight(true)
    -- label:Resize(label:Width() /2, label:Height() /2)
    -- label:SetCanResizeWidth(false) label:SetCanResizeHeight(false)

    -- label:SetVisible(false)
end

function ui_obj:ui_created()
    log("UI created!")

    self.game_ui_created = true

    for i = 1, #self.ui_created_callbacks do

        local f = self.ui_created_callbacks[i]
        f()
    end
end

function ui_obj:add_ui_created_callback(callback)

    if not is_function(callback) then
        logerr("add_ui_created_callback() called, but the callback argument passed is not a function!")
        return false
    end

    if self.game_ui_created then
        -- trigger immediately
        callback()
    else
        self.ui_created_callbacks[#self.ui_created_callbacks+1] = callback
    end
end

--- TODO create floating notifications that can be X'd out of. WH3, probably?
function ui_obj:notify(str)
    local mct_button = self:get_mct_button()
    if not is_uicomponent(mct_button) then
        logerr("ui:notify() triggered but the mct button doesn't exist yet?")
        return false
    end

    if not is_string(str) then
        -- errmsg
        --return false
    end

    -- change the counter on the num label to be +1, set it visible if it's not
    local label = UIComponent(mct_button:Find("label_notify"))

    label:SetVisible(true)

    self.notify_num = self.notify_num + 1
    local num = self.notify_num

    label:SetStateText(tostring(num))

    -- highlight the MCT button because people are dolts
    mct_button:StartPulseHighlight(5, "active")
end

-- clear notifs
function ui_obj:clear_notifs()
    local mct_button = self:get_mct_button()
    if not is_uicomponent(mct_button) then
        -- errmsg
        return false
    end

    local label = UIComponent(mct_button:Find("label_notify"))
    label:SetStateText("")
    label:SetVisible(false)

    mct_button:StopPulseHighlight("active")

    self.notify_num = 0
end

-- stash a popup for when MCT is opened
function ui_obj:stash_popup(key, text, two_buttons, button_one_callback, button_two_callback)
    -- verify shit is alright
    --[[if not is_string(key) then
        err("stash_popup() called, but the key passed is not a string!")
        return false
    end

    if not is_string(text) then
        err("stash_popup() called, but the text passed is not a string!")
        return false
    end

    if is_nil(two_buttons) then
        two_buttons = false
    end

    if not is_boolean(two_buttons) then
        err("stash_popup() called, but the two_buttons arg passed is not a boolean!")
        return false
    end

    if not two_buttons then button_two_callback = function() end end]]

    -- save it locally!
    self.stashed_popups[#self.stashed_popups+1] = {
        key = key,
        text = text,
        two_buttons = two_buttons,
        button_one_callback = button_one_callback,
        button_two_callback = button_two_callback,
    }
end

function ui_obj:clear_stashed_popups()

end

function ui_obj:trigger_stashed_popups()
    local stashed_popups = self.stashed_popups

    local num_total = #stashed_popups

    if num_total == 0 then 
        -- do nothing?
    elseif num_total == 1 then
        -- just trigger it right away
        local stashed_popup = stashed_popups[1]
        self:create_popup(
            stashed_popup.key, 
            stashed_popup.text, 
            stashed_popup.two_buttons,
            stashed_popup.button_one_callback,
            stashed_popup.button_two_callback
        )
    else
        -- trigger 1 right away, and trigger the rest consecutively when button one/button two are clicked

        local bloop = {}

        -- backwards loop - start at the end and work backwards. necessary since we need to read entries from "bloop", since index 1 has to create index 2 popup
        for i = num_total, 1, -1 do
            local stashed_popup = stashed_popups[i]

            if i == num_total then
                bloop[i] = stashed_popup
            else -- edit the "stashed_popup" to trigger the next popup when it's closed
                local next_popup = bloop[i+1]
                local create_next_popup = function()
                    self:create_popup(
                        next_popup.key,
                        next_popup.text,
                        next_popup.two_buttons,
                        next_popup.button_one_callback,
                        next_popup.button_two_callback
                    )
                end

                local one_callback = stashed_popup.button_one_callback
                stashed_popup.button_one_callback = function() one_callback() create_next_popup() end

                local two_callback = stashed_popup.button_two_callback
                stashed_popup.button_two_callback = function() two_callback() create_next_popup() end

                bloop[i] = stashed_popup
            end
        end

        -- trigger the first one!
        local stashed_popup = bloop[1]

        self:create_popup(
            stashed_popup.key,
            stashed_popup.text,
            stashed_popup.two_buttons,
            stashed_popup.button_one_callback,
            stashed_popup.button_two_callback
        )
    end

    self.stashed_popups = {}
end

-- if it's the frontend, trigger popup immediately;
-- else, add the notify button + highlight
function ui_obj:create_popup(key, text, two_buttons, button_one_callback, button_two_callback)
    -- define the popup callback function - triggered immediately in frontend, and triggered when you open the panel for other modes (or immediately if panel is opened)

    -- check if the UI has been created; if not, stash it as a ui created callback
    if not self.game_ui_created then
        self:add_ui_created_callback(function() self:create_popup(key, text, two_buttons, button_one_callback, button_two_callback) end)
        return
    end

    if __game_mode == __lib_type_frontend then
        -- create the popup immediately
        VLib.TriggerPopup(key, text, two_buttons, button_one_callback, button_two_callback, nil, self.panel)
    else
        -- check if the MCT panel is currently open; if it is, trigger immediately, otherwise stash that ish

        if self.opened then
            -- ditto, make immejiately
            VLib.TriggerPopup(key, text, two_buttons, button_one_callback, button_two_callback, nil, self.panel)
        else

            -- add the notify, and stash the popup for when the panel is opened.
            self:notify()

            self:stash_popup(key, text, two_buttons, button_one_callback, button_two_callback)
        end
    end
end

--- TODO if no layout object is supplied, assume "Main" page
---@param mod_obj MCT.Mod
---@param page MCT.Page
function ui_obj:set_selected_mod(mod_obj, page)
    local ok, err = pcall(function()
    -- deselect the former one
    local former = mct:get_selected_mod()
    if former then
        former:clear_uics(false)
    end

    local former_uic = self.selected_mod_row
    if is_uicomponent(former_uic) then
        former_uic:SetState("active")
    end

    local mod_key = mod_obj:get_key()
    local page_key = page:get_key()
    local row_uic = page:get_row_uic()

    if is_uicomponent(row_uic) then
        logf("Setting %s page %s as selcted!", mod_key, page_key)

        row_uic:SetState("selected")
        mct:set_selected_mod(mod_obj, page)
        self.selected_mod_row = row_uic

        -- for i,page_uic in ipairs(mct:get_selected_mod()._page_uics) do
        --     page_uic:SetVisible(true)
        --     page_uic:SetState("active")
        -- end

        local uic = self.mod_settings_panel
        local list = find_uicomponent(uic, "list_view")
        local box = find_uicomponent(list, "list_clip", "list_box")
        box:DestroyChildren()
        box:Layout()
        box:Resize(list:Width(), list:Height())
    
        self:set_title(mod_obj)
        page:populate(box)

        box:Layout()
        
        --- Needed? TODO
        self:set_actions_states()

        core:trigger_custom_event("MctPanelPopulated", {["mct"] = mct, ["ui_obj"] = self, ["mod"] = mod_obj, ["page"] = page})
        
    end end) if not ok then VLib.Error(err) end
end

function ui_obj:open_frame()
    -- check if one exists already
    local ok, msg = pcall(function()
    local test = self.panel

    self.opened = true
    Registry:clear_changed_settings(true)

    -- make a new one!
    if not is_uicomponent(test) then
        self:create_panel()

        local ordered_mod_keys = {}
        for n in pairs(mct._registered_mods) do
            if n ~= "mct_mod" then
                table.insert(ordered_mod_keys, n)
            end
        end

        table.sort(ordered_mod_keys)

        -- create the MCT mod first
        table.insert(ordered_mod_keys, 1, "mct_mod")

        for i,n in ipairs(ordered_mod_keys) do
            local mod_obj = mct:get_mod_by_key(n)
            self:new_mod_row(mod_obj)
        end

        local mct_mod = mct:get_mod_by_key("mct_mod")
        self:set_selected_mod(mct_mod, mct_mod:get_main_page())
        self.mod_row_list_box:Layout()

        --- The listener for selecting an individual mod
        core:add_listener(
            "MctRowClicked",
            "ComponentLClickUp",
            function(context)
                local row = UIComponent(context.component)
                return UIComponent(row:Parent()) == self.mod_row_list_box
            end,
            function(context)
                --- TODO handle page UICs!

                local uic = UIComponent(context.component)
                local mod_key = uic:GetProperty("mct_mod")

                if not mod_key then
                    logf("No mct_mod property for the UIcomponent clicked!")
                    return
                end

                
                local mod_obj = mct:get_mod_by_key(mod_key)
                local layout_key = uic:GetProperty("mct_layout")

                if not mod_obj then
                    --- errmsg
                    return
                end
                
                logf("mct_mod: %s", mod_key)
                logf("mct_page: %s", layout_key)

                local selected_mod, selected_layout = mct:get_selected_mod()

                -- we've selected a subheader of the currently selected mod - check if it's a different subheader than currently selected!
                if is_string(layout_key) and layout_key ~= "" then
                    --- TODO test if this layout is different than the currently selected layout
                    uic:SetState("selected")

                    if selected_layout:get_key() ~= layout_key then
                        self:set_selected_mod(mod_obj, mod_obj:get_page_with_key(layout_key))
                    end
                else
                    if selected_mod ~= mod_obj then
                        -- trigger stuff on the right
                        self:set_selected_mod(mod_obj, mod_obj:get_main_page())
                    else
                        -- we aren't changing rows, keep this one selected.
                        uic:SetState("selected")
                    end
                end

            end,
            true
        )

    else
        test:SetVisible(true)
    end

    -- clear notifications + trigger any stashed popups
    self:trigger_stashed_popups()
    self:clear_notifs()

    core:trigger_custom_event("MctPanelOpened", {["mct"] = mct, ["ui_obj"] = self})

end) if not ok then logerr(msg) end
end

function ui_obj:set_actions_states()
    -- self:populate_profiles_dropdown_box()
    -- local profiles_dropdown = self.profiles_dropdown

    -- -- --- the smol buttons next to profiles dropdown
    -- -- local profiles_new = find_uicomponent(profiles_dropdown, "mct_profiles_new")
    -- -- local profiles_delete = find_uicomponent(profiles_dropdown, "mct_profiles_delete")
    -- -- local profiles_edit = find_child_uicomponent(profiles_dropdown, "mct_profiles_edit")

    -- -- local current_profile = Settings:get_selected_profile()
    -- -- local current_profile_name = current_profile.__name

    -- --- TODO profiles_new lock when you have too many profiles.
    -- -- profiles_new is always allowed!
    -- _SetState(profiles_new, "active")

    -- -- if not io.open(Settings.__import_profiles_file, "r") then
    -- --     _SetState(profiles_import, "inactive")
    -- -- else
    -- --     _SetState(profiles_import, "active")
    -- -- end

    -- -- lock the Profiles Delete button if it's the default profile
    -- if current_profile_name == "Default Profile" then
    --     _SetState(profiles_delete, "inactive")
    --     _SetTooltipText(profiles_delete, common.get_localised_string("mct_profiles_delete_tt_inactive"), false)

    --     _SetState(profiles_edit, "inactive")
    --     _SetTooltipText(profiles_edit, common.get_localised_string("mct_profiles_edit_tt_inactive"), false)
    -- else
    --     -- there is a current profile; enable delete
    --     _SetState(profiles_delete, "active")
    --     _SetTooltipText(profiles_delete, common.get_localised_string("mct_profiles_delete_txt"), false)

    --     _SetState(profiles_edit, "active")
    --     _SetTooltipText(profiles_edit, common.get_localised_string("mct_profiles_edit_tt"), false)
    -- end
end

--- TODO?
function ui_obj:set_selected_profile()

end

-- function ui_obj:populate_profiles_dropdown_box()
--     local profiles_dropdown = self.profiles_dropdown
--     if not is_uicomponent(profiles_dropdown) then
--         logerr("populate_profiles_dropdown_box() called, but the actions_panel UIC is not found!")
--         return false
--     end

--     core:remove_listener("mct_profiles_ui")
--     core:remove_listener("mct_profiles_ui_selected")
--     core:remove_listener("mct_profiles_ui_close")

--     -- get necessary bits & bobs
--     local popup_menu = find_uicomponent(profiles_dropdown, "popup_menu")
--     local popup_list = find_uicomponent(popup_menu, "popup_list")
--     local selected_tx = find_uicomponent(profiles_dropdown, "dy_selected_txt")

--     selected_tx:SetStateText("")
    
--     popup_list:DestroyChildren()

--     --- get all currently extant Profiles and order them
--     local all_profiles = mct.settings:get_all_profile_keys()
--     local ordered_profiles = all_profiles

--     for i,k in ipairs(ordered_profiles) do
--         if k == "Default Profile" then
--             table.remove(ordered_profiles, i)
--             break
--         end
--     end

--     table.sort(ordered_profiles, function(a, b)
--         return a < b
--     end)

--     --- always have Default Profile first!
--     table.insert(ordered_profiles, 1, "Default Profile")


--     local w,h = 0,0
--     if is_table(ordered_profiles) and next(ordered_profiles) ~= nil then

--         _SetState(profiles_dropdown, "active")

--         local selected_boi = mct.settings:get_selected_profile_key()

--         for i = 1, #ordered_profiles do
--             local profile_key = ordered_profiles[i]
--             local profile = mct.settings:get_profile(profile_key)

--             local new_entry = core:get_or_create_component(profile_key, "ui/vandy_lib/dropdown_option", popup_list)
--             new_entry:SetVisible(true)
            
--             _SetTooltipText(new_entry, profile.__description or "", true)

--             new_entry:SetCanResizeHeight(true)
--             new_entry:SetCanResizeWidth(true)

--             local off_y = 5 + (new_entry:Height() * (i-1))
--             new_entry:SetDockingPoint(2)
--             new_entry:SetDockOffset(0, off_y)

--             -- new_entry:Resize(new_entry:Width(), new_entry:Height() * 1.2)
--             w,h = new_entry:Dimensions()

--             local txt = find_uicomponent(new_entry, "row_tx")
    
--             _SetStateText(txt, profile.__name)

--             new_entry:SetCanResizeHeight(false)
--             new_entry:SetCanResizeWidth(false)

--             if profile_key == selected_boi then
--                 _SetState(new_entry, "selected")

--                 -- add the value's text to the actual dropdown box
--                 _SetStateText(selected_tx, profile.__name)
--                 _SetTooltipText(profiles_dropdown, profile.__description or "", true)
--             else
--                 _SetState(new_entry, "unselected")
--             end
--         end

--         local border_top = find_uicomponent(popup_menu, "border_top")
--         local border_bottom = find_uicomponent(popup_menu, "border_bottom")
        
--         border_top:SetCanResizeHeight(true)
--         border_top:SetCanResizeWidth(true)
--         border_bottom:SetCanResizeHeight(true)
--         border_bottom:SetCanResizeWidth(true)
    
--         popup_list:SetCanResizeHeight(true)
--         popup_list:SetCanResizeWidth(true)

--         w,h = w*1.1, h*#ordered_profiles + 10

--         popup_list:Resize(w, h)
--         --popup_list:MoveTo(popup_menu:Position())
--         popup_list:SetDockingPoint(2)
--         --popup_list:SetDocKOffset()

    
--         popup_menu:SetCanResizeHeight(true)
--         popup_menu:SetCanResizeWidth(true)
--         popup_list:SetCanResizeHeight(false)
--         popup_list:SetCanResizeWidth(false)
        
--         -- w, h = popup_list:Bounds()
--         popup_menu:Resize(w,h)
--     else
--         -- if there are no profiles, lock the dropdown and set text to empty
--         _SetState(profiles_dropdown, "inactive")

--         -- clear out the selected text
--         _SetStateText(selected_tx, "")
--     end

--     core:add_listener(
--         "mct_profiles_ui",
--         "ComponentLClickUp",
--         function(context)
--             return context.string == "mct_profiles_dropdown"
--         end,
--         function(context)
--             local box = UIComponent(context.component)
--             local menu = find_uicomponent(box, "popup_menu")
--             if is_uicomponent(menu) then
--                 if menu:Visible() then
--                     menu:SetVisible(false)
--                 else
--                     menu:SetVisible(true)
--                     menu:RegisterTopMost()
--                     menu:Resize(w, h)
--                     -- next time you click something, close the menu!
--                     core:add_listener(
--                         "mct_profiles_ui_close",
--                         "ComponentLClickUp",
--                         true,
--                         function(c)
--                             if box:CurrentState() == "selected" then
--                                 _SetState(box, "active")
--                             end

--                             menu:SetVisible(false)
--                             menu:RemoveTopMost()

--                             -- core:remove_listener("mct_profiles_ui_selected")
--                             core:remove_listener("mct_profiles_ui_close")
--                         end,
--                         false
--                     )
--                 end
--             end
--         end,
--         true
--     )

--     -- Set Selected listeners
--     core:add_listener(
--         "mct_profiles_ui_selected",
--         "ComponentLClickUp",
--         function(context)
--             local uic = UIComponent(context.component)
            
--             return UIComponent(uic:Parent()):Id() == "popup_list" and uicomponent_descended_from(uic, "mct_profiles_dropdown")
--         end,
--         function(context)
--             -- core:remove_listener("mct_profiles_ui_selected")
--             core:remove_listener("mct_profiles_ui_close")

--             local old_selected_uic = nil
--             local new_selected_uic = UIComponent(context.component)

--             local old_key = mct.settings:get_selected_profile_key()
--             local new_key = new_selected_uic:Id()

--             local popup_list = UIComponent(new_selected_uic:Parent())
--             local popup_menu = UIComponent(popup_list:Parent())
--             local dropdown_box = UIComponent(popup_menu:Parent())

--             local function change_profiles()
--                 if is_string(old_key) then
--                     old_selected_uic = find_uicomponent(popup_list, old_key)
--                     if is_uicomponent(old_selected_uic) then
--                         _SetState(old_selected_uic, "unselected")
--                     end
--                 end
    
--                 _SetState(new_selected_uic, "selected")
        
--                 -- set the menu invisible and unclick the box
--                 if dropdown_box:CurrentState() == "selected" then
--                     _SetState(dropdown_box, "active")
--                 end
        
--                 popup_menu:RemoveTopMost()
--                 popup_menu:SetVisible(false)
    
--                 Settings:apply_profile_with_key(new_key)
--                 self:set_actions_states()
--             end

--             if Registry:has_pending_changes() then
--                 VLib.TriggerPopup(
--                     "mct_profiles_change",
--                     string.format(common.get_localised_string("mct_profiles_change_popup"), old_key),
--                     true,
--                     function()
--                         -- change profiles
--                         -- self.panel:LockPriority()
--                         change_profiles()
--                     end,
--                     function()
--                         -- self.panel:LockPriority()
--                         -- don't change profiles
--                     end,
--                     self.panel
--                 )
--             else
--                 change_profiles()
--             end
--         end,
--         true
--     )
-- end

-- function ui_obj:create_profiles_dropdown()
--     -- local mod_settings_panel = self.mod_settings_panel
--     local left_panel = self.left_panel

--     local profiles_dropdown = core:get_or_create_component("mct_profiles_dropdown", "ui/vandy_lib/dropdown_button", left_panel)
--     profiles_dropdown:SetDockingPoint(8)
--     profiles_dropdown:SetDockOffset(0, profiles_dropdown:Height() * 1.2)

--     local popup_menu = find_uicomponent(profiles_dropdown, "popup_menu")
--     popup_menu:SetVisible(false)

--     self.profiles_dropdown = profiles_dropdown

--     local bw = profiles_dropdown:Height() * 0.8
--     local bh = bw
--     local templ_path = "ui/templates/square_small_button"

--     local i = 1 local m = 3

--     local function new_button(key, image)
--         local btn = core:get_or_create_component(key, templ_path, profiles_dropdown)
--         btn:SetCanResizeHeight(true)
--         btn:SetCanResizeWidth(true)
--         btn:Resize(bw, bh)

--         --- TODO alternatively, use a friggin layoutengine`
--         --- TODO utilize m and handle this a bit better
--         btn:SetDockingPoint(8)
--         btn:SetDockOffset((bw + (bw*(i-3)) * 1.1), bh * 1.1)

--         btn:SetTooltipText(common.get_localised_string(key.."_tt"), true)

--         btn:SetImagePath(VLib.SkinImage(image))

--         find_uicomponent(btn, "icon"):SetVisible(false)

--         i = i + 1
--     end
    
--     new_button("mct_profiles_new", "icon_plus_small")
--     new_button("mct_profiles_edit", "icon_rename")
--     new_button("mct_profiles_delete", "icon_delete")

--     self:add_profiles_dropdown_listeners()
-- end

-- function ui_obj:add_profiles_dropdown_listeners()
--     core:add_listener(
--         "mct_profiles_new",
--         "ComponentLClickUp",
--         function(context)
--             return context.string == "mct_profiles_new"
--         end,
--         function(context)
--             local btn = UIComponent(context.component)
--             if is_uicomponent(btn) then
--                 _SetState(btn, 'active')
--             end

--             VLib.TriggerPopup(
--                 "mct_profiles_new",
--                 "",
--                 true,
--                 function()

--                 end,
--                 function(p)

--                 end,
--                 function(popup)
--                     local tx = find_uicomponent(popup, "DY_text")
--                     -- local both_
            
--                     tx:SetVisible(true)
--                     tx:SetDockingPoint(5)
--                     local ow,oh = popup:Width() * 0.9, popup:Height() * 0.8
--                     tx:Resize(ow, oh)
--                     tx:SetDockOffset(1, -35)
                    
--                     -- TODO plop in a pretty title
--                     local default_text = common.get_localised_string("mct_profiles_new")

--                     local tx = find_uicomponent(popup, "DY_text")
            
--                     local function set_text(str)
--                         local w,h = tx:TextDimensionsForText(str)
--                         tx:ResizeTextResizingComponentToInitialSize(w,h)

--                         _SetStateText(tx, str)
                
--                         tx:Resize(ow,oh)
--                         tx:ResizeTextResizingComponentToInitialSize(ow,oh)
--                     end

--                     set_text(default_text)

--                     local xx,yy = tx:GetDockOffset()
--                     yy = yy - 40
--                     tx:SetDockOffset(xx,yy)

--                     local current_name = "Profile Name"
--                     local current_desc = "Profile Description"
--                     local current_name_str = common.get_localised_string("mct_profiles_current_name") -- "Current name: %s"

--                     --- TODO add in a "clear text" button on both inputs
--                     local input = core:get_or_create_component("text_input", "ui/common ui/text_box", popup)
--                     input:SetDockingPoint(8)
--                     input:SetDockOffset(0, input:Height() * -6.5)
--                     input:SetStateText(current_name)
--                     input:SetInteractive(true)

--                     input:Resize(input:Width() * 0.75, input:Height())

--                     input:PropagatePriority(popup:Priority())

--                     local description_input = core:get_or_create_component("description_input", "ui/common ui/text_box", popup)
--                     description_input:SetDockingPoint(8)
--                     description_input:SetDockOffset(0, description_input:Height() * -4.5)
--                     _SetStateText(description_input, current_desc)
--                     description_input:SetInteractive(true)

--                     description_input:Resize(description_input:Width() * 0.75, description_input:Height())

--                     description_input:PropagatePriority(popup:Priority())

            
--                     find_uicomponent(popup, "both_group"):SetVisible(true)
--                     find_uicomponent(popup, "ok_group"):SetVisible(false)

--                     local button_tick = find_uicomponent(popup, "both_group", "button_tick")
--                     _SetState(button_tick, "inactive")

--                     core:get_tm():repeat_real_callback(function()
--                         local current_key = input:GetStateText()
--                         current_desc = description_input:GetStateText()

--                         local test = mct.settings:test_profile_with_key(current_key)

--                         if test == true then
--                             _SetState(button_tick, "active")

--                             current_name = current_key
--                             set_text(default_text)
--                         else
--                             _SetState(button_tick, "inactive")
--                             current_name = ""

--                             set_text(default_text .. test)
--                         end
--                     end, 100, "profiles_check_name")

--                     core:add_listener(
--                         "mct_profiles_popup_close",
--                         "ComponentLClickUp",
--                         function(context)
--                             return context.string == "button_tick" or context.string == "button_cancel"
--                         end,
--                         function(context)
--                             core:get_tm():remove_real_callback("profiles_check_name")
--                             delete_component(popup)

--                             local panel = self.panel
--                             if is_uicomponent(panel) then
--                                 panel:LockPriority()
--                             end

--                             if context.string == "button_tick" then
--                                 mct.settings:add_profile_with_key(current_name, current_desc)
--                             end
--                         end,
--                         false
--                     )
--                 end,
--                 self.panel
--             )
--         end,
--         true
--     )

--     core:add_listener(
--         "mct_profiles_edit",
--         "ComponentLClickUp",
--         function(context)
--             return context.string == "mct_profiles_edit"
--         end,
--         function(context)
--             logf("Clicking profiles_edit")
--             local btn = UIComponent(context.component)
--             btn:SetState("active")

--             local default_text = common.get_localised_string("mct_profiles_new")
--             local current_name = ""
--             local current_desc = ""

--             VLib.TriggerPopup(
--                 "mct_profiles_edit",
--                 default_text,
--                 true,
--                 function(p)
--                     mct.settings:rename_profile(mct.settings:get_selected_profile_key(), current_name, current_desc)

--                     self:set_actions_states()
--                 end,
--                 function(p)

--                 end,
--                 function(p)
--                     -- TODO plop in a pretty title
--                     local tx = find_uicomponent(p, "DY_text")
--                     local ow, oh = p:Width() * 0.9, p:Height() * 0.8
            
--                     local function set_text(str)
--                         local w,h = tx:TextDimensionsForText(str)
--                         tx:ResizeTextResizingComponentToInitialSize(w,h)

--                         _SetStateText(tx, str)
                
--                         tx:Resize(ow,oh)
--                         tx:ResizeTextResizingComponentToInitialSize(ow,oh)
--                     end

--                     set_text(default_text)

--                     local xx,yy = tx:GetDockOffset()
--                     yy = yy - 40
--                     tx:SetDockOffset(xx,yy)

--                     local current_profile = mct.settings:get_selected_profile()
--                     current_name = current_profile.__name
--                     current_desc = current_profile.__description
--                     local current_name_str = common.get_localised_string("mct_profiles_current_name") -- "Current name: %s"

--                     --- TODO add in a "restore default" button on both inputs
--                     local input = core:get_or_create_component("text_input", "ui/common ui/text_box", p)
--                     input:SetDockingPoint(8)
--                     input:SetDockOffset(0, input:Height() * -6.5)
--                     _SetStateText(input, current_name)
--                     input:SetInteractive(true)

--                     input:Resize(input:Width() * 0.75, input:Height())

--                     input:PropagatePriority(p:Priority())

--                     local description_input = core:get_or_create_component("description_input", "ui/common ui/text_box", p)
--                     description_input:SetDockingPoint(8)
--                     description_input:SetDockOffset(0, description_input:Height() * -4.5)
--                     _SetStateText(description_input, current_desc)
--                     description_input:SetInteractive(true)

--                     description_input:Resize(description_input:Width() * 0.75, description_input:Height())

--                     description_input:PropagatePriority(p:Priority())

            
--                     -- find_uicomponent(p, "both_group"):SetVisible(true)
--                     -- find_uicomponent(p, "ok_group"):SetVisible(false)

--                     local button_tick = find_uicomponent(p, "both_group", "button_tick")
--                     _SetState(button_tick, "inactive")

--                     core:get_tm():repeat_real_callback(function()
--                         local current_key = input:GetStateText()
--                         current_desc = description_input:GetStateText()

--                         --- TODO prevent renaming Default Profile!
--                         local test = mct.settings:test_profile_with_key(current_key)
                        
--                         --- ignore the "same key" error if this profile is that key!
--                         if test == true or (current_key == mct.settings:get_selected_profile_key()) then
--                             _SetState(button_tick, "active")

--                             current_name = current_key
--                             set_text(default_text)
--                         else
--                             _SetState(button_tick, "inactive")
--                             current_name = ""

--                             set_text(default_text .. test)
--                         end
--                     end, 100, "profiles_check_name")                 

--                 end,
--                 self.panel
--             )
--         end,
--         true
--     )


--     core:add_listener(
--         "mct_profiles_delete",
--         "ComponentLClickUp",
--         function(context)
--             return context.string == "mct_profiles_delete" and mct.settings:get_selected_profile_key() ~= "Default Profile"
--         end,
--         function(context)
--             local btn = UIComponent(context.component)
--             btn:SetState("active")

--             -- trigger a popup with "Are you Sure?"
--             -- yes: clear this profile from mct.settings, and selected_profile as well (just deselect profile entirely?) (probably!)
--             -- no: close the popup, do naught
--             ui_obj:create_popup(
--                 "mct_profiles_delete_popup",
--                 string.format(common.get_localised_string("mct_profiles_delete_popup"), mct.settings:get_selected_profile_key()),
--                 true,
--                 function(context) -- "button_tick" triggered for yes
--                     mct.settings:delete_profile_with_key(mct.settings:get_selected_profile_key())
--                 end,
--                 function(context) -- "button_cancel" triggered for no
--                     -- do nothing!
--                 end
--             )
--         end,
--         true
--     )
-- end

function ui_obj:close_frame()
    delete_component(self.panel)

    --core:remove_listener("left_or_right_pressed")
    core:remove_listener("MctRowClicked")
    core:remove_listener("MCT_SectionHeaderPressed")
    core:remove_listener("mct_highlight_finalized_any_pressed")

    --- TODO use a self.uics[key]=uic table instead of this
    -- clear saved vars
    self.panel = nil
    self.mod_row_list_view = nil
    self.mod_row_list_box = nil
    -- self.mod_details_panel = nil
    self.mod_settings_panel = nil
    self.selected_mod_row = nil
    self.actions_panel = nil

    self.opened = false

    Registry:clear_changed_settings(true)

    -- clear uic's attached to mct_options
    local mods = mct:get_mods()
    for _, mod in pairs(mods) do
        --mod:clear_uics_for_all_options()
        mod:clear_uics(true)
    end
end

function ui_obj:create_panel()
    -- create the new window and set it visible
    if self.panel then return end
    local panel = core:get_or_create_component("mct_options", "ui/templates/panel_frame", nil)
    panel:SetVisible(true)

    panel:PropagatePriority(200)

    --new_frame:RegisterTopMost()

    panel:LockPriority()

    -- resize the panel
    panel:SetCanResizeWidth(true) panel:SetCanResizeHeight(true)
    local sw, sh = core:get_screen_resolution()
    local pw, ph = sw*0.7, sh*0.65
    panel:Resize(pw, ph)
    panel:SetDockingPoint(5)
    panel:SetDockOffset(0, 0)
    panel:ResizeCurrentStateImage(0, pw, ph)
    panel:ResizeCurrentStateImage(1, pw, ph)
    panel:SetCanResizeWidth(false) panel:SetCanResizeHeight(false)
    panel:SetMoveable(true)

    self.panel = panel

    self:create_left_panel()
    self:create_right_panel()
    -- self:create_profiles_dropdown()
end

function ui_obj:create_left_panel()
    local panel = self.panel

    local img_path = VLib.SkinImage("parchment_texture.png")

    -- create image background
    local left_panel_bg = core:get_or_create_component("left_panel_bg", "ui/vandy_lib/image", panel)
    left_panel_bg:SetImagePath(img_path)
    left_panel_bg:SetCurrentStateImageMargins(0, 50, 50, 50, 50)
    left_panel_bg:SetDockingPoint(1)
    left_panel_bg:SetDockOffset(20, 10)
    left_panel_bg:SetCanResizeWidth(true) left_panel_bg:SetCanResizeHeight(true)
    left_panel_bg:Resize(panel:Width() * 0.15, panel:Height() * 0.8)
    -- left_panel_bg:SetVisible(true)

    local w,h = left_panel_bg:Dimensions()

    -- make the stationary title (on left_panel_bg, doesn't scroll)
    local left_panel_title = core:get_or_create_component("left_panel_title", "ui/templates/parchment_divider_title", left_panel_bg)
    _SetStateText(left_panel_title, common.get_localised_string("mct_ui_mods_header"))
    left_panel_title:Resize(left_panel_bg:Width(), left_panel_title:Height())
    left_panel_title:SetDockingPoint(2)
    left_panel_title:SetDockOffset(0,0)

    -- create listview
    local left_panel_listview = core:get_or_create_component("left_panel_listview", "ui/templates/listview", left_panel_bg)
    left_panel_listview:SetCanResizeWidth(true) left_panel_listview:SetCanResizeHeight(true)
    left_panel_listview:Resize(w, h-left_panel_title:Height()-10) 
    left_panel_listview:SetDockingPoint(2)
    left_panel_listview:SetDockOffset(0, left_panel_title:Height()+5)

    local w,h = left_panel_listview:Dimensions()

    local lclip = find_uicomponent(left_panel_listview, "list_clip")
    lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
    lclip:SetDockingPoint(2)
    lclip:Resize(w,h)

    local lbox = find_uicomponent(lclip, "list_box")
    lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
    lbox:SetDockingPoint(2)
    lbox:Resize(w,h)
    
    -- save the listview and list box into the obj
    self.mod_row_list_view = left_panel_listview
    self.mod_row_list_box = lbox
    self.left_panel = left_panel_bg
end

function ui_obj:create_right_panel()
    local panel = self.panel
    local img_path = VLib.SkinImage("parchment_texture.png")
    local left_panel = self.left_panel

    -- right side
    local mod_settings_panel = core:get_or_create_component("mod_settings_panel", "ui/vandy_lib/image", panel)
    mod_settings_panel:SetImagePath(img_path)
    mod_settings_panel:SetCurrentStateImageMargins(0, 50, 50, 50, 50) -- 50/50/50/50 margins
    mod_settings_panel:SetDockingPoint(6)
    mod_settings_panel:SetDockOffset(-20, 10)
    mod_settings_panel:SetCanResizeWidth(true) mod_settings_panel:SetCanResizeHeight(true)

    -- edit the name
    local title = core:get_or_create_component("title", "ui/templates/panel_title", mod_settings_panel)
    title:Resize(title:Width() * 1.35, title:Height())

    title:SetDockingPoint(2)
    title:SetDockOffset(0, -title:Height() * 0.8)

    local title_text = core:get_or_create_component("title_text", "ui/vandy_lib/text/paragraph_header", title)
    title_text:Resize(title:Width() * 0.8, title:Height() * 0.7)
    title_text:SetDockingPoint(5)

    mod_settings_panel:Resize(panel:Width() - (left_panel:Width() + 60), panel:Height() * 0.95 - title:Height(), false)

    --- Create the close button
    local close_button_uic = core:get_or_create_component("button_mct_close", "ui/templates/round_small_button", mod_settings_panel)
    close_button_uic:SetImagePath(VLib.SkinImage("icon_cross.png"))
    close_button_uic:SetTooltipText("Close panel", true)
    close_button_uic:SetDockingPoint(3)
    close_button_uic:SetDockOffset(-5, -close_button_uic:Height() * 1.2)

    local w,h = mod_settings_panel:Dimensions()

    local mod_settings_listview = core:get_or_create_component("list_view", "ui/mct/listview", mod_settings_panel)
    mod_settings_listview:SetDockingPoint(1)
    mod_settings_listview:SetDockOffset(0, 10)
    mod_settings_listview:SetCanResizeWidth(true) mod_settings_listview:SetCanResizeHeight(true)
    mod_settings_listview:Resize(w,h-20)

    local list_clip = find_uicomponent(mod_settings_listview, "list_clip")
    list_clip:SetCanResizeWidth(true) list_clip:SetCanResizeHeight(true)
    list_clip:SetDockingPoint(1)
    list_clip:SetDockOffset(0, 0)
    list_clip:Resize(w,h-20)

    local list_box = find_uicomponent(list_clip, "list_box")
    list_box:SetCanResizeWidth(true) list_box:SetCanResizeHeight(true)
    list_box:SetDockingPoint(1)
    list_box:SetDockOffset(0, 0)
    list_box:Resize(w,h-20)

    list_box:Layout()

    local l_handle = find_uicomponent(mod_settings_listview, "vslider")
    l_handle:SetDockingPoint(6)
    l_handle:SetDockOffset(-20, 0)

    mod_settings_listview:SetVisible(true)

    self.mod_title = title_text
    self.mod_settings_panel = mod_settings_panel
end

function ui_obj:set_title(mod_obj)
    local mod_title = self.mod_title
    local title = mod_obj:get_title()

    mod_title:SetStateText(title)
end

--- TODO move this all into option_obj:populate() which is a Super called by the individual types!
--- Add a new option row
---@param option_obj MCT.Option
---@param this_layout UIC
function ui_obj:new_option_row_at_pos(option_obj, this_layout)
    local panel = self.mod_settings_panel

    local w,h = this_layout:Width(), panel:Height()
    --- TODO better dynamic height! Handle Arrays and the like!
    w = w * 0.95
    h = h * 0.12

    option_obj:ui_create_option_base(this_layout, w, h)
end

---@param mod_obj MCT.Mod
function ui_obj:new_mod_row(mod_obj)
    local row = core:get_or_create_component(mod_obj:get_key(), "ui/vandy_lib/row_header", self.mod_row_list_box)
    row:SetVisible(true)
    row:SetCanResizeHeight(true) row:SetCanResizeWidth(true)
    row:Resize(self.mod_row_list_view:Width() * 0.95, row:Height() * 1.8)
    row:SetDockingPoint(2)

    --- This hides the +/- button from the row headers.
    for i = 0, row:NumStates() -1 do
        row:SetState(row:GetStateByIndex(i))
        row:SetCurrentStateImageOpacity(1, 0)
    end
    
    row:SetState("active")
    row:SetProperty("mct_mod", mod_obj:get_key())
    row:SetProperty("mct_layout", mod_obj:get_main_page():get_key())

    local txt = find_uicomponent(row, "dy_title")

    txt:Resize(row:Width() * 0.9, row:Height() * 0.9)
    txt:SetDockingPoint(2)
    txt:SetDockOffset(10,0)

    local txt_txt = mod_obj:get_title()
    local author_txt = mod_obj:get_author()

    if not is_string(txt_txt) then
        txt_txt = "No title assigned"
    end

    txt_txt = txt_txt .. "\n" .. author_txt

    _SetStateText(txt, txt_txt)

    local tt = mod_obj:get_tooltip_text()

    if is_string(tt) and tt ~= "" then
        row:SetTooltipText(tt, true)
    end

    --- create the subpages for this mod row and then hide them to be reopened when this mod is selected.
    for page_key,page_obj in pairs(mod_obj._pages) do
        --- if page_obj is the  main_page then don't do anything (because that row header has already been made!)
        if page_obj ~= mod_obj:get_main_page() then
            page_obj:create_row_uic()
        end
    end

    mod_obj:get_main_page():set_row_uic(row)
    mod_obj:set_row_uic(row)
end

--- TODO add MCT button to the Esc menu(?)
function ui_obj:create_mct_button(parent)
    local mct_button = core:get_or_create_component("button_mct", "ui/templates/round_small_button", parent)

    mct_button:SetImagePath(VLib.SkinImage("icon_options"))
    mct_button:SetTooltipText(common.get_localised_string("mct_mct_mod_title"), true)
    mct_button:SetVisible(true)

    core:add_listener(
        "MctButton",
        "ComponentLClickUp",
        function(context)
            return context.string == "button_mct"
        end,
        function(context)
            core:get_tm():real_callback(function()
                get_mct():open_panel()
            end, 5, "mct_button")
        end,
        true
    )

    return mct_button
end

core:add_listener(
    "mct_close_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_close" and uicomponent_descended_from(UIComponent(context.component), "mct_options")
    end,
    function(context)
        -- check if MCT was finalized or no changes were done during the latest UI operation       
        if Registry:has_pending_changes() then
            -- if Settings.__settings_changed then
                mct:finalize()
            -- end
        end
        
        ui_obj:close_frame()
    end,
    true
)

core:add_listener(
    "mct_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_options"
    end,
    function(context)
        ui_obj:open_frame()
    end,
    true
)

core:add_listener(
    "mct_panel_moved",
    "ComponentMoved",
    function(context)
        return context.string == "mct_options"
    end,
    function(context)
        local uic = UIComponent(context.component)
        local x,y = uic:Position()
        local w,h = uic:Bounds()

        local sw,sh = core:get_screen_resolution()

        -- local 
        x = math.clamp(x, 0, sw-w)
        y = math.clamp(y, 0, sh-h)

        local function f() uic:MoveTo(x, y) end
        local i = 1
        local k = "mct_panel_moved"
        
        ---@type timer_manager
        local tm = core:get_static_object("timer_manager")
        tm:real_callback(f, i, k)
    end,
    true
)


core:add_listener(
    "mct_revert_to_defaults_pressed",
    "ComponentLClickUp",
    function(context)
        local uic = UIComponent(context.component)
        return context.string == "mct_revert_to_defaults" and uic:GetProperty("mct_mod") and uic:GetProperty("mct_option")
    end,
    function(context)
        local uic = UIComponent(context.component)
        local mod_key = uic:GetProperty("mct_mod")
        local option_key = uic:GetProperty("mct_option")

        local mod_obj = mct:get_mod_by_key(mod_key)

        if mod_obj then
            local option_obj = mod_obj:get_option_by_key(option_key)
            if option_obj then
                option_obj:revert_to_default()
                -- option_obj:set_de 
            end
        end
    end,
    true
)

return ui_obj