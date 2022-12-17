---- MCT UI Object. INTERNAL USE ONLY.

-- TODO differentiate betterly between "vlib_ui" which is general UI stuff, and "mct_ui" which is stuff specific to, welp.
-- TODO cleanup crew.
--- TODO move into /core/ 

local this_path = GLib.ThisPath(...)

---@class MCT.UI : MCT.System
local UI_Main = {
    -- UICs --

    ---@type UIC the MCT button
    mct_button = nil,

    -- script dummy
    dummy = nil,

    -- full panel
    ---@type UIC
    panel = nil,

    title = nil,

    -- left side UICs
    mod_row_list_view = nil,
    mod_row_list_box = nil,

    -- right bottom UICs
    right_panel = nil,
    right_panel_title = nil,

    top_bar = nil,

    -- currently selected mod UIC
    selected_mod_row = nil,

    game_ui_created = false,

    ui_created_callbacks = {},

    -- stashed popups, stored within this table, enjoy.
    stashed_popups = {},

    -- if the panel is openeded or closededed
    opened = false,
    notify_num = 0,

    ---@type table<string, boolean> These are tables that the MCT panel cannot open in front of; therefore, we'll hardlock the button when these panels are visible
    fullscreen_panels = {
        custom_battle = true,
    }
}

local mct = get_mct()

-- --- TODO load these elsewhere!
-- local ui_path = "script/vlib/mct/core/ui/"

-- ---@type MCT.UI.Profiles
-- local UI_Profiles = GLib.LoadModule("profiles", ui_path)

-- ---@type MCT.UI.Notifications
-- local UI_Notifications = GLib.LoadModule("notifications", ui_path)

-- local Registry = mct:get_registry()

local log,logf,logerr,logerrf = get_vlog("[mct_ui]")

function UI_Main:init()
    local name = nil
    if __game_mode == __lib_type_battle then
        name = "battle"
    elseif __game_mode == __lib_type_campaign then
        name = "campaign"
    elseif __game_mode == __lib_type_frontend then
        name = "frontend"
    end

    local m = GLib.LoadModule(name, this_path .. "contexts/")
    m:init()
end

function UI_Main:get_mct_button()
    return self.mct_button
end

function UI_Main:is_open()
    return self.opened
end

function UI_Main:listen_fullscreen_panels()
    log("Triggering listeners for fullscreen_panels")
    if core:is_frontend() then
        core:add_listener(
            "MCT_StateChange",
            "FrontendScreenTransition",
            true,
            function(context)
                -- log("Doin a listen for a change in frontend menu!")
                local button = self:get_mct_button()
                -- if this is a hardlocked panel, lock the button
                if self.fullscreen_panels[context.string] then
                    -- log("This frontend menu is fullscreen, locking MCT")
                    button:SetState("inactive")
                    button:SetTooltipText("Cannot use MCT while this panel is opened", true)
                else
                    button:SetState("active")
                end
            end,
            true
        )
    --- TODO these later.
    elseif core:is_campaign() then

    elseif core:is_battle() then

    end
end

---@param uic UIC
function UI_Main:set_mct_button(uic)
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

function UI_Main:ui_created()
    log("UI created!")

    self.game_ui_created = true
    self:listen_fullscreen_panels()

    for i = 1, #self.ui_created_callbacks do

        local f = self.ui_created_callbacks[i]
        f()
    end
end

function UI_Main:add_ui_created_callback(callback)

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
function UI_Main:notify(str)
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
function UI_Main:clear_notifs()
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
function UI_Main:stash_popup(key, text, two_buttons, button_one_callback, button_two_callback)
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

function UI_Main:clear_stashed_popups()

end

function UI_Main:trigger_stashed_popups()
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
function UI_Main:create_popup(key, text, two_buttons, button_one_callback, button_two_callback)
    -- define the popup callback function - triggered immediately in frontend, and triggered when you open the panel for other modes (or immediately if panel is opened)

    -- check if the UI has been created; if not, stash it as a ui created callback
    if not self.game_ui_created then
        self:add_ui_created_callback(function() self:create_popup(key, text, two_buttons, button_one_callback, button_two_callback) end)
        return
    end

    if __game_mode == __lib_type_frontend then
        -- create the popup immediately
        GLib.TriggerPopup(key, text, two_buttons, button_one_callback, button_two_callback, nil, self.panel)
    else
        -- check if the MCT panel is currently open; if it is, trigger immediately, otherwise stash that ish

        if self.opened then
            -- ditto, make immejiately
            GLib.TriggerPopup(key, text, two_buttons, button_one_callback, button_two_callback, nil, self.panel)
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
function UI_Main:set_selected_mod(mod_obj, page)
    local ok, err = pcall(function()
    -- deselect the former one
    local former = mct:get_selected_mod()
    if former then
        former:clear_uics(false)
    end

    local former_uic = self.selected_mod_row
    if former_uic and is_uicomponent(former_uic) then
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

        ---@type UIC
        local uic = self.right_panel
        uic:DestroyChildren()
        -- local list = find_uicomponent(uic, "list_view")
        -- local box = find_uicomponent(list, "list_clip", "list_box")
        -- box:DestroyChildren()
        -- box:Layout()
        -- box:Resize(list:Width(), list:Height())
    
        self:set_title(mod_obj)
        page:populate(uic)

        -- box:Layout()

        core:trigger_custom_event("MctPanelPopulated", {["mct"] = mct, ["ui_obj"] = self, ["mod"] = mod_obj, ["page"] = page})
        
    end end) if not ok then GLib.Error(err) end
end

function UI_Main:open_frame(provided_panel, is_pre_campaign)
    -- check if one exists already
    local ok, msg = pcall(function()
    local test = self.panel

    if is_uicomponent(test) and test:Visible() == nil then
        self:close_frame(true)
        ---@diagnostic disable-next-line
        test = nil
    end

    self.opened = true
    mct:get_registry():clear_changed_settings()

    -- make a new one!
    if provided_panel or not is_uicomponent(test) then
        self:create_panel(provided_panel)

        local ordered_mod_keys = {}
        for n in pairs(mct._registered_mods) do
            if n ~= "mct_mod" then
                table.insert(ordered_mod_keys, n)
            end
        end

        table.sort(ordered_mod_keys)

        -- create the MCT mod first
        table.insert(ordered_mod_keys, 1, "mct_mod")

        for i,mod_key in ipairs(ordered_mod_keys) do
            local mod_obj = mct:get_mod_by_key(mod_key)
            if mod_obj then
                self:new_mod_row(mod_obj)
            else
                logf("Trying to create a new mod row for MCT.Mod with key %s, but none exists with that key!", mod_key)
            end
        end

        local mct_mod = mct:get_mod_by_key("mct_mod")
        ---@cast mct_mod MCT.Mod
        self:set_selected_mod(mct_mod, mct_mod:get_main_page())
        self.mod_row_list_box:Layout()

        core:remove_listener("MctRowClicked")
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
                if mod_obj == selected_mod then
                    --- TODO test if this layout is different than the currently selected layout
                    uic:SetState("selected")

                    if selected_layout:get_key() ~= layout_key then
                        self:set_selected_mod(mod_obj, mod_obj:get_page_with_key(layout_key))
                    end
                else
                    -- if selected_mod ~= mod_obj then
                        -- trigger stuff on the right
                        self:set_selected_mod(mod_obj, mod_obj:get_page_with_key(layout_key))
                    -- else
                    --     -- we aren't changing rows, keep this one selected.
                    --     uic:SetState("selected")
                    -- end
                end

            end,
            true
        )

    else
        self.panel:SetVisible(true)
    end

    -- clear notifications + trigger any stashed popups
    self:trigger_stashed_popups()
    self:clear_notifs()

    core:trigger_custom_event("MctPanelOpened", {["mct"] = mct, ["ui_obj"] = self})

end) if not ok then logerr(msg) end
end


function UI_Main:close_frame(already_dead)
    if not already_dead then delete_component(self.panel) end

    --core:remove_listener("left_or_right_pressed")
    core:remove_listener("MctRowClicked")
    core:remove_listener("MCT_SectionHeaderPressed")
    core:remove_listener("mct_highlight_finalized_any_pressed")

    --- TODO use a self.uics[key]=uic table instead of this
    -- clear saved vars
    self.panel = nil
    self.title = nil
    self.mod_row_list_view = nil
    self.mod_row_list_box = nil

    self.left_panel = nil
    self.right_panel = nil
    self.top_bar = nil
    self.selected_mod_row = nil

    self.opened = false

    mct:get_registry():clear_changed_settings()

    -- clear uic's attached to mct_options
    local mods = mct:get_mods()
    for _, mod in pairs(mods) do
        --mod:clear_uics_for_all_options()
        mod:clear_uics(true)
    end
end

function UI_Main:create_panel(provided_panel)
    -- create the new window and set it visible
    if self.panel then return end

    logf("Creating the new panel!")
    out("Creating the new panel!")

    local sw, sh = core:get_screen_resolution()
    local panel
    local pw, ph = sw*0.7, sh*0.65
    if provided_panel then
        panel = provided_panel
        pw, ph = panel:Width(), panel:Height()
    else
        panel = core:get_or_create_component("mct_options", "ui/mct/frame")
        panel:PropagatePriority(200)
        panel:LockPriority()
        panel:SetMoveable(true)
        panel:SetDockingPoint(5)
        panel:SetDockOffset(0, 0)
    end

    panel:SetVisible(true)

    -- resize the panel
    panel:SetCanResizeWidth(true) panel:SetCanResizeHeight(true)
    panel:Resize(pw, ph)
    panel:SetCanResizeCurrentStateImageHeight(0, true)
    panel:SetCanResizeCurrentStateImageWidth(0, true)
    
    panel:SetCanResizeCurrentStateImageHeight(1, true)
    panel:SetCanResizeCurrentStateImageWidth(1, true)
    
    panel:ResizeCurrentStateImage(0, pw, ph)
    panel:ResizeCurrentStateImage(1, pw, ph)
    panel:SetCanResizeWidth(false) panel:SetCanResizeHeight(false)

    self.panel = panel

    -- edit the name
    local title = core:get_or_create_component("title", "ui/templates/panel_title", panel)
    title:Resize(title:Width() * 1.35, title:Height())
    
    title:SetDockingPoint(11)
    title:SetDockOffset(0, title:Height() / 2)
    
    local title_text = core:get_or_create_component("title_text", "ui/vandy_lib/text/paragraph_header", title)
    title_text:Resize(title:Width() * 0.8, title:Height() * 0.7)
    title_text:SetDockingPoint(5)

    --- TODO any tooltip?
    title_text:SetStateText("Mod Configuration Tool")

    self.title = title_text

    --- Create the close button
    local close_button_uic = core:get_or_create_component("button_mct_close", "ui/templates/round_small_button", panel)
    close_button_uic:SetImagePath(GLib.SkinImage("icon_cross.png"))
    close_button_uic:SetTooltipText("Close panel", true)
    close_button_uic:SetDockingPoint(3+9)
    close_button_uic:SetDockOffset(-close_button_uic:Width() / 2, close_button_uic:Height() / 2)

    local ih = ph * 0.85
    local lw = pw * 0.22
    local rw = pw * 0.75

    local xo, yo = 20, 20

    self:create_left_panel(lw, ih, xo, yo)
    self:create_right_panel(rw, ih, xo, yo)

    self:create_top_bar(panel:Width() * 0.98, panel:Height() - ih - 15 - yo, 0, 20)

    core:get_ui_root():Layout()
end

--- Create the top bar which holds some information and global buttons.
function UI_Main:create_top_bar(w, h, xo, yo)
    local panel = self.panel

    local top_bar = core:get_or_create_component("top_bar", "ui/campaign ui/script_dummy", panel)
    top_bar:Resize(w, h)
    top_bar:SetDockingPoint(2)
    top_bar:SetDockOffset(xo, yo)

    --- an autosizer list to hold buttons (help page, notifications, whatever else is needed)
    local buttons_holder = core:get_or_create_component("buttons_holder", "ui/groovy/layouts/hlist", top_bar)
    buttons_holder:SetDockingPoint(6)
    buttons_holder:SetDockOffset(-15, 0)

    --- TODO the holder on the top left for current state info (ie. )
    local info_holder = core:get_or_create_component("info_holder", "ui/groovy/holders/intense_holder", top_bar)
    info_holder:SetDockingPoint(7)
    info_holder:SetDockOffset(10, -10)
    info_holder:Resize(top_bar:Width() * 0.2, top_bar:Height() * 0.85)

    -- TODO state the currently loaded settings, the state, and add a settings button w/ popup to change it.
    local currently_loaded_txt = core:get_or_create_component("currently_loaded", "ui/vandy_lib/text/dev_ui", info_holder)
    currently_loaded_txt:SetStateText(mct:get_state_text())
    currently_loaded_txt:Resize(info_holder:Width() * 0.8, info_holder:Height() * 0.9)
    -- currently_loaded_txt:SetDockingPoint(1)
    -- currently_loaded_txt:SetDockOffset(0, 0)
    currently_loaded_txt:SetTextHAlign("left")
    currently_loaded_txt:SetTextVAlign("centre")
    currently_loaded_txt:SetTextXOffset(5, 5)
    currently_loaded_txt:SetTextYOffset(0, 0)

    local button_edit_state = core:get_or_create_component("button_edit_state", "ui/templates/round_extra_small_button", info_holder)
    button_edit_state:SetTooltipText("Edit State||Change the view settings!", true)
    button_edit_state:SetImagePath("ui/skins/default/icon_custom_options.png")

    self.top_bar = top_bar
    
    --- TODO "save" button?
    self:create_profiles_button(buttons_holder)
    self:create_notifications_button(buttons_holder)
    self:create_help_button(buttons_holder)
end

function UI_Main:create_profiles_button(parent)
    local profiles_button = core:get_or_create_component("button_mct_profiles", "ui/templates/square_medium_text_button", parent)
    profiles_button:SetDockingPoint(4)
    profiles_button:Resize(profiles_button:Width() * 0.7, profiles_button:Height())
    profiles_button:SetDockOffset(10, 0)

    find_uicomponent(profiles_button, "button_txt"):SetStateText("Profiles")
end


function UI_Main:create_notifications_button(parent)
    -- local notifications_button = core:get_or_create_component("button_mct_notifications", "ui/groovy/notifications_button", panel)
    local notifications_button = core:get_or_create_component("button_mct_notifications", "ui/templates/round_medium_button", parent)

    -- notifications_button:SetDockingPoint(6)
    -- notifications_button:SetDockOffset(-30, 0)
    
    notifications_button:SetCanResizeHeight(true)
    notifications_button:SetCanResizeWidth(true)
    notifications_button:Resize(notifications_button:Width() * 0.8, notifications_button:Height() * 0.8)
    notifications_button:SetCanResizeHeight(false)
    notifications_button:SetCanResizeWidth(false)

    notifications_button:SetImagePath("ui/skins/default/icon_end_turn_notification_generic.png")
    notifications_button:SetTooltipText("Notifications||Review any notifications", true)

    local label_num = core:get_or_create_component("label_num", "ui/groovy/label_num", notifications_button)
    label_num:SetTooltipText("", true)
    label_num:SetStateText("5")

    label_num:SetDockOffset(15, -20)

    --- TODO dynamic tooltip w/ different state text
    --- TODO label showing number of unread notifications
    --- TODO pulse (or something) if there's urgent notifs
end

function UI_Main:create_help_button(parent)
    local help_button = core:get_or_create_component("button_mct_help", "ui/templates/round_medium_button", parent)

    -- help_button:SetDockingPoint(6)
    -- help_button:SetDockOffset(-30, 0)
    
    help_button:SetCanResizeHeight(true)
    help_button:SetCanResizeWidth(true)
    help_button:Resize(help_button:Width() * 0.8, help_button:Height() * 0.8)
    help_button:SetCanResizeHeight(false)
    help_button:SetCanResizeWidth(false)

    help_button:SetState("inactive")

    help_button:SetImagePath("ui/skins/default/icon_question_mark.png")
    help_button:SetTooltipText("Help||This will be enabled soon!", true)
end

--- TODO hide/show the left panel w/ quick animation, not urgent by any means.
function UI_Main:swap_left_panel(is_open)


end

--- TODO the button to hide/show the left panel
function UI_Main:create_left_panel(ew, eh, xo, yo)
    local panel = self.panel

    local img_path = GLib.SkinImage("parchment_texture.png")

    -- create image background
    local left_panel = core:get_or_create_component("left_panel", "ui/groovy/image", panel)
    left_panel:SetImagePath(img_path)
    left_panel:SetCurrentStateImageMargins(0, 50, 50, 50, 50)
    left_panel:SetDockingPoint(7)
    left_panel:SetDockOffset(xo, -yo)
    left_panel:SetCanResizeWidth(true) left_panel:SetCanResizeHeight(true)
    left_panel:Resize(ew, eh)
    -- left_panel_bg:SetVisible(true)

    local w,h = left_panel:Dimensions()

    -- make the stationary title (on left_panel_bg, doesn't scroll)
    local left_panel_title = core:get_or_create_component("left_panel_title", "ui/templates/parchment_divider_title", left_panel)
    left_panel_title:SetStateText(common.get_localised_string("mct_ui_mods_header"))
    left_panel_title:Resize(w, left_panel_title:Height())
    left_panel_title:SetDockingPoint(2)
    left_panel_title:SetDockOffset(0,0)

    -- create listview
    local left_panel_listview = core:get_or_create_component("left_panel_listview", "ui/templates/listview", left_panel)
    left_panel_listview:SetCanResizeWidth(true) left_panel_listview:SetCanResizeHeight(true)
    left_panel_listview:Resize(w, h-left_panel_title:Height()-5) 
    left_panel_listview:SetDockingPoint(2)
    left_panel_listview:SetDockOffset(0, left_panel_title:Height()+5)

    local w,h = left_panel_listview:Dimensions()

    local lclip = find_uicomponent(left_panel_listview, "list_clip")
    lclip:SetCanResizeWidth(true) lclip:SetCanResizeHeight(true)
    lclip:SetDockingPoint(1)
    lclip:Resize(w,h)

    local lbox = find_uicomponent(lclip, "list_box")
    lbox:SetCanResizeWidth(true) lbox:SetCanResizeHeight(true)
    lbox:SetDockingPoint(1)
    lbox:Resize(w,h)

    local vslider = find_uicomponent(left_panel_listview, "vslider")
    local x,y = vslider:GetDockOffset()
    vslider:SetDockOffset(0, y)
    
    -- save the listview and list box into the obj
    self.mod_row_list_view = left_panel_listview
    self.mod_row_list_box = lbox
    self.left_panel = left_panel
end

function UI_Main:create_right_panel(ew, eh, xo, yo)
    local panel = self.panel
    local img_path = GLib.SkinImage("parchment_texture.png")

    -- right side
    local right_panel = core:get_or_create_component("right_panel", "ui/groovy/image", panel)
    right_panel:SetImagePath(img_path)
    right_panel:SetCurrentStateImageMargins(0, 50, 50, 50, 50) -- 50/50/50/50 margins

    right_panel:SetDockingPoint(9)
    right_panel:SetDockOffset(-xo, -yo)

    right_panel:SetCanResizeWidth(true) right_panel:SetCanResizeHeight(true)
    right_panel:Resize(ew, eh)
    right_panel:SetCanResizeWidth(false) right_panel:SetCanResizeHeight(false)

    -- make the stationary title (on left_panel_bg, doesn't scroll)
    local right_panel_title = core:get_or_create_component("right_panel_title", "ui/templates/parchment_divider_title", right_panel)
    right_panel_title:SetStateText("Test Text")
    right_panel_title:Resize(ew * 0.8, right_panel_title:Height())
    right_panel_title:SetDockingPoint(2)
    right_panel_title:SetDockOffset(0,0)

    local right_panel_holder = core:get_or_create_component("right_panel_holder", "ui/campaign ui/script_dummy", right_panel)
    right_panel_holder:Resize(right_panel:Width(), right_panel:Height() - right_panel_title:Height() - 5)
    right_panel_holder:SetDockingPoint(8)

    self.mod_title = right_panel_title
    self.right_panel = right_panel_holder
end

function UI_Main:set_title(mod_obj)
    local mod_title = self.mod_title
    local title = mod_obj:get_title()

    mod_title:SetStateText(title)
end

--- TODO move this all into option_obj:populate() which is a Super called by the individual types!
--- Add a new option row
---@param option_obj MCT.Option
---@param this_layout UIC
function UI_Main:new_option_row_at_pos(option_obj, this_layout, w, h)
    -- local panel = self.right_side_panel

    -- local w,h = this_layout:Width(), panel:Height()
    -- --- TODO better dynamic height! Handle Arrays and the like!
    -- w = w * 0.95
    -- h = h * 0.12

    GLib.Log("[MCT] Option row height is %d", h)

    option_obj:ui_create_option_base(this_layout, w, h)

    return w,h
end

core:declare_lookup_listener("component_click_up", "ComponentLClickUp", function(context) return context.component end)

---comment
---@param comp UIComponent
---@param f function
---@param persistent boolean
---@param disable boolean
function UI_Main:OnComponentClick(comp, f, persistent, disable)
    if not is_uicomponent(comp) then return end
    if not is_function(f) then return end

    local id = "component_click_"..comp:Id()
    local addr = comp:Address()

    if disable then
        core:remove_lookup_listener_callback("component_click_up", id)
        return
    end

    core:add_lookup_listener_callback(
        "component_click_up",
        id,
        addr,
        function()
            ModLog("component_click_up")
            if comp:Visible() == nil then
                core:remove_lookup_listener_callback("component_click_up", id)
                return
            end

            f()
        end,
        persistent
    )
end

--- TODO move row_header creation to a GLib method or summat

---@param mod_obj MCT.Mod
function UI_Main:new_mod_row(mod_obj)
    local row = core:get_or_create_component(mod_obj:get_key(), "ui/vandy_lib/row_header", self.mod_row_list_box)
    row:SetVisible(true)
    row:SetCanResizeHeight(true) row:SetCanResizeWidth(true)
    row:Resize(self.mod_row_list_view:Width() * 0.95, 34 * 1.8)
    row:SetDockingPoint(2)

    --- This hides the +/- button from the row headers.
    for i = 0, row:NumStates() -1 do
        row:SetState(row:GetStateByIndex(i))
        row:SetCurrentStateImageOpacity(1, 0)
    end
    
    row:SetState("active")
    row:SetProperty("mct_mod", mod_obj:get_key())
    row:SetProperty("mct_layout", mod_obj:get_main_page():get_key())

    local txt_uic = find_uicomponent(row, "dy_title")

    txt_uic:Resize(row:Width() - 28, row:Height() * 0.9)
    txt_uic:SetDockingPoint(4)
    txt_uic:SetDockOffset(0,0)
    txt_uic:SetTextVAlign("centre")
    txt_uic:SetTextHAlign("left")
    txt_uic:SetTextXOffset(5, 0)
    txt_uic:SetTextYOffset(0, 0)


    local title_txt = mod_obj:get_title()
    local author_txt = mod_obj:get_author()

    if not is_string(title_txt) then
        title_txt = "No title assigned"
    end

    title_txt = title_txt .. "\n" .. author_txt

    txt_uic:SetStateText(title_txt)

    local tt = mod_obj:get_tooltip_text()

    if is_string(tt) and tt ~= "" then
        row:SetTooltipText(tt, true)
    end

    local button_more_options = core:get_or_create_component("button_more_options", "ui/mct/more_options_button", row)
    button_more_options:SetProperty("mct_mod", mod_obj:get_key())

    -- local commands = GLib.CommandManager.commands.mct_mod_commands

    -- common.set_context_value("mct_mod_commands", commands)
    button_more_options:SetContextObject(cco("CcoScriptObject", "mct_mod_commands"))
    button_more_options:SetDockingPoint(6)
    button_more_options:SetDockOffset(-8, 0)
    button_more_options:SetTooltipText("More Options", true)

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
function UI_Main:create_mct_button(parent)
    local mct_button = core:get_or_create_component("button_mct", "ui/templates/round_small_button", parent)
    logf("Calling create_mct_button!")

    mct_button:SetImagePath(GLib.SkinImage("icon_options"))
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

    self:set_mct_button(mct_button)

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
        if mct:get_registry():has_pending_changes() then
            -- if Settings.__settings_changed then
                mct:finalize()
            -- end
        end
        
        UI_Main:close_frame()
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
        UI_Main:open_frame()
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
    "MCT_EscClosed",
    "UITrigger",
    function(context) GLib.Log("UI trigger: " .. context.string) return context.string == "mct_panel_closed" end,
    function(context)
        GLib.Log("MCT panel closed UI trigger!!")
        UI_Main:close_frame(true)
    end,
    true
)

--- TODO move to GLib
local function inv(obj, e)
    ModLog("Investigate object from event " .. e)

    -- for k,v in pairs(obj) do
    --     ModLog("\tFound "..e.."."..k.."()")
    -- end

    local mt = getmetatable(obj)

    if mt then
        for k,v in pairs(mt) do
            if is_function(v) then
                ModLog("\tFound " .. e.."."..k.."()")
            elseif k == "__index" then
                ModLog("\tIn index!")
                for ik,iv in pairs(v) do
                    if is_function(iv) then
                        ModLog("\t\tFound " .. e.."."..ik.."()")
                    else
                        ModLog("\t\tFound " .. e.."."..ik)
                    end
                end
            else
                ModLog("\tFound " .. e.."."..k)
            end
        end
    end
end

--- TODO move this into Command Manager
--- TODO hook this up more situationally
core:add_listener(
    "MCT_ContextCommands",
    "ContextTriggerEvent",
    function(context)
        ModLog("ContextTriggerEvent: " .. context.string)
        return context.string:starts_with("mct_")
    end,
    function(context)
        local command_string = context.string
        local command_context = string.match(command_string, "([^|]-)|")
        local command_key = string.match(command_string, "|([^|]-)|")

        --- TODO multiple params, accept a table here
        local param = string.match(command_string, "|([^|]-)$")

        ModLog("Context: " .. command_context)
        ModLog("Command: " .. command_key)
        ModLog("Param: " .. param)
        
        local this_context = GLib.CommandManager.commands[command_context]

        if this_context then
            ModLog("ContextTriggerEvent context is: " .. command_context)
            ModLog("Command is: " .. command_key)

            local this_command = this_context[command_key]
            -- local last_component_guid = common.get_context_value("CcoScriptObject", command_context, "LastComponentThatSetOurValue")
    
            -- if is_string(last_component_guid) and last_component_guid ~= "" then
                -- ModLog("Last component guid is: " .. last_component_guid)
                -- local last_commponent = cco("CcoComponent", last_component_guid)
                -- ModLog("Cco is: " .. tostring(last_commponent))

                -- common.call_context_command("CcoScriptObject", command_context, "SetStringValue('')")
    
                --- TODO instead of this being hardcoded per context, it should probably just be that we use `SetProperty("param_1", mct_mod)` etc., and loop through param_i where i = 1, 10 until we can't find a property, and then just pass all those forward.

                --- Figure out the context we need from the component!
                if command_context == "mct_mod_commands" then
                    -- local mod_key = last_commponent:Call("ParentContext.ParentContext.ParentContext.ParentContext.ParentContext.GetProperty('mct_mod')")

                    local mod_key = param
            
                    ModLog("Running an mct_mod_command, for mod: " .. mod_key)
                    --- TODO get the relevant properties from the component
                    local mod_obj = mct:get_mod_by_key(mod_key)
                    if mod_obj then
                        this_command.callback(mod_obj)
                    end
                end
            -- end
        end

    end,
    true
)

core:add_listener(
    "mct_profiles_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_profiles"
    end,
    function(context)
        ---@type MCT.UI.Profiles
        local UI_Profiles = mct:get_system_ui("profiles")
        UI_Profiles:open()
    end,
    true
)

core:add_listener(
    "mct_notifications_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_notifications"
    end,
    function(context)
        ---@type MCT.UI.Notifications
        local UI_Notifications = mct:get_system_ui("notifications")
        UI_Notifications:open()
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

UI_Main:init()

return UI_Main