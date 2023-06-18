---- MCT UI Object. INTERNAL USE ONLY.

-- TODO differentiate betterly between "vlib_ui" which is general UI stuff, and "mct_ui" which is stuff specific to, welp.
-- TODO cleanup crew.
--- TODO move into /core/ 

local this_path = GLib.ThisPath(...)

---@class MCT.UI : Class
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
                    button:SetTooltipText(common.get_localised_string("mct_mct_mod_title") ..  "||[[col:red]]Cannot use MCT while this panel is opened[[/col]]", false)
                else
                    button:SetState("active")
                    button:SetTooltipText(common.get_localised_string("mct_mct_mod_title"), false)
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

            -- -- add the notify, and stash the popup for when the panel is opened.
            -- self:notify()

            self:stash_popup(key, text, two_buttons, button_one_callback, button_two_callback)
        end
    end
end

--- TODO if no layout object is supplied, assume "Main" page
---@param mod_obj MCT.Mod?
---@param page MCT.Page?
function UI_Main:set_selected_mod(mod_obj, page)

    local left_panel = self.left_panel
    local scrollbar = find_uicomponent(left_panel, "list_view", "vslider")
    local handle = find_uicomponent(scrollbar, "handle")
    local handle_x,handle_y = handle:Position()

    -- deselect the former one
    local former = mct:get_selected_mod()
    if former then
        -- former:clear_uics(false)
        former:toggle_subrows(false, true)
    end

    local former_uic = self.selected_mod_row
    if former_uic and is_uicomponent(former_uic) then
        former_uic:SetState("active")
    end

    -- if mod_obj / page aren't provided, check MCT for the selected mod / page; if none there, provide default.
    if not mod_obj then
        mod_obj, page = mct:get_selected_mod()

        if not mod_obj then
            mod_obj = mct:get_mod_by_key("mct_mod")
            page = mod_obj:get_main_page()
        end
    end

    local mod_key = mod_obj:get_key()
    local page_key = page:get_key()
    local row_uic = page:get_row_uic()

    mod_obj:toggle_subrows(true, true)

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
    
        self:set_title(mod_obj)
        page:populate(uic)

        core:trigger_custom_event("MctPanelPopulated", {["mct"] = mct, ["ui_obj"] = self, ["mod"] = mod_obj, ["page"] = page})
        
    end

    -- scroll to the selected mod
    core:get_tm():real_callback(function()
        handle:MoveTo(handle_x, handle_y)
    end, 10)
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
                mod_obj:create_row(self.mod_row_list_box)
            else
                logf("Trying to create a new mod row for MCT.Mod with key %s, but none exists with that key!", mod_key)
            end
        end

        self:set_selected_mod()

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

                local new_layout = nil

                if layout_key == "main" then
                    new_layout = mod_obj:get_main_page()
                else
                    new_layout = mod_obj:get_settings_page_with_key(layout_key)
                end

                if not mod_obj then
                    --- errmsg
                    return
                end

                if mod_obj:is_disabled() then
                    return
                end
                
                logf("mct_mod: %s", mod_key)
                logf("mct_page: %s", layout_key)

                local selected_mod, selected_layout = mct:get_selected_mod()

                -- we've selected a subheader of the currently selected mod - check if it's a different subheader than currently selected!
                if mod_obj == selected_mod then
                    --- test if this layout is different than the currently selected layout
                    uic:SetState("selected")

                    if selected_layout:get_key() ~= layout_key then
                        self:set_selected_mod(mod_obj, new_layout)
                    end
                else
                    -- if selected_mod ~= mod_obj then
                        -- trigger stuff on the right
                        self:set_selected_mod(mod_obj, new_layout)
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

    self:get_mct_button():SetState("active")
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
        panel = core:get_or_create_component("mct_options", "ui/groovy/frames/basic")
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

    local title = find_uicomponent(panel, "panel_title")
    
    title:SetStateText("Mod Configuration Tool")
    self.title = title

    -- edit the name
    -- local title = core:get_or_create_component("title", "ui/templates/panel_title", panel)
    -- title:Resize(title:Width() * 1.35, title:Height())
    
    -- title:SetDockingPoint(11)
    -- title:SetDockOffset(0, title:Height() / 2)
    
    -- local title_text = core:get_or_create_component("title_text", "ui/vandy_lib/text/paragraph_header", title)
    -- title_text:Resize(title:Width() * 0.8, title:Height() * 0.7)
    -- title_text:SetDockingPoint(5)

    -- --- TODO any tooltip?
    -- title_text:SetStateText("Mod Configuration Tool")

    -- self.title = title_text

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

    --- TODO temp disabled
    info_holder:SetVisible(false)

    -- TODO state the currently loaded settings, the state, and add a settings button w/ popup to change it.
    local currently_loaded_txt = core:get_or_create_component("currently_loaded", "ui/groovy/text/fe_default", info_holder)
    currently_loaded_txt:SetStateText(mct:get_mode_text())
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

    local how_it_works = core:get_or_create_component("how_it_works_holder", "ui/groovy/holders/intense_holder", top_bar)
    how_it_works:SetDockingPoint(5)
    how_it_works:SetDockOffset(-20, 0)
    how_it_works:Resize(how_it_works:Width() * 0.8, how_it_works:Height() * 0.7)

    local how_it_works_txt = core:get_or_create_component("how_it_works_txt", "ui/groovy/text/fe_default", how_it_works)
    how_it_works_txt:SetDockingPoint(2)
    how_it_works_txt:SetTextVAlign("centre")
    how_it_works_txt:SetTextHAlign("centre")
    how_it_works_txt:Resize(how_it_works:Width() * 0.7, how_it_works:Height() * 0.6)
    how_it_works_txt:SetTextXOffset(5, 5)
    how_it_works_txt:SetTextYOffset(5, 5)

    local how_it_works_button = core:get_or_create_component("how_it_works_button", "ui/groovy/buttons/icon_button", how_it_works)
    how_it_works_button:SetDockingPoint(2)
    how_it_works_button:SetDockOffset(0, how_it_works_txt:Height() * 0.5 + 5)
    how_it_works_button:SetImagePath("ui/skins/default/icon_question_mark.png", 0)

    do
        if mct:in_campaign_registry() then
            how_it_works_txt:SetStateText("Campaign Registry")
            how_it_works_button:SetTooltipText("Campaign Registry||MCT is loaded in a .\n\n [[img:mct_campaign]][[/img]]Campaign-specific settings changed in this campaign will have their settings changed in the save, but it won't change for other campaigns or the main menu.\n [[img:mct_registry]]Global settings will have their value changed everywhere.", true)
        else
            how_it_works_txt:SetStateText("Global Registry")
            how_it_works_button:SetTooltipText("Global Registry||MCT is loaded in the Global Registry (ie., outside of a campaign save).\n\n [[img:mct_campaign]][[/img]]Campaign-specific settings changed in the main menu will be applied to any newly-created campaigns, and will hold their value until changed in the main menu.\n [[img:mct_registry]]Global settings will have their value changed everywhere.", true)
        end
    end

    self.top_bar = top_bar
    
    self:create_profiles_button(buttons_holder)
    self:create_help_button(buttons_holder)
    self:create_save_button(buttons_holder)
    self:create_multiplayer_holder()
end

--- Create the Multiplayer Holder UIComponent
--- It handles mulitplayer information (host/etc), and allows for importing/exporting settings in frontend.
function UI_Main:create_multiplayer_holder()
    local bar = self.top_bar

    local holder = core:get_or_create_component("multiplayer_holder", "ui/campaign ui/script_dummy", bar)
    holder:SetDockingPoint(4)
    holder:SetDockOffset(12, 0)
    holder:Resize(holder:Width(), bar:Height() * .95)

    --- TODO host name
    local name_tx = core:get_or_create_component("txt_host_name", "ui/groovy/text/fe_bold", holder)
    name_tx:SetDockingPoint(2)
    name_tx:SetStateText("Host's name goes here")
    name_tx:Resize(holder:Width() * .9, name_tx:Height())

    --- TODO import/export settings for campaign
    local share_settings = core:get_or_create_component("button_share_settings", "ui/templates/square_small_button", holder)
    share_settings:SetDockingPoint(8)
    share_settings:SetDockOffset(0, -10)

    share_settings:SetTooltipText("Share Settings||Either import or export the settings depending on who you are!", true)
end

function UI_Main:set_how_it_works(text, tooltip)
    local how_it_works_txt = find_uicomponent(self.top_bar, "how_it_works_holder", "how_it_works_txt")
    if not is_uicomponent(how_it_works_txt) then return end

    if is_string(text) then
        how_it_works_txt:SetStateText(text)
    end

    if is_string(tooltip) then
       how_it_works_txt:SetTooltipText(tooltip, true)
    end
end

-- edit currently_loaded text based on mct:get_mode_text
function UI_Main:update_currently_loaded_text()
    local currently_loaded_txt = find_uicomponent(self.top_bar, "info_holder", "currently_loaded")
    if not is_uicomponent(currently_loaded_txt) then return end

    currently_loaded_txt:SetStateText(mct:get_mode_text())
end

function UI_Main:create_profiles_button(parent)
    local profiles_button = core:get_or_create_component("button_mct_profiles", "ui/templates/square_medium_text_button", parent)
    profiles_button:SetDockingPoint(4)
    profiles_button:Resize(profiles_button:Width() * 0.7, profiles_button:Height())
    profiles_button:SetDockOffset(10, 0)

    
    profiles_button:SetTooltipText("Profiles||This will be enabled soon!", true)
    profiles_button:SetState("inactive")

    find_uicomponent(profiles_button, "button_txt"):SetStateText("Profiles")
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

-- Create save button
function UI_Main:create_save_button(parent)
    local save_button = core:get_or_create_component("button_mct_save", "ui/templates/round_medium_button", parent)
    save_button:SetCanResizeHeight(true)
    save_button:SetCanResizeWidth(true)
    save_button:Resize(save_button:Width() * 0.8, save_button:Height() * 0.8)
    save_button:SetCanResizeHeight(false)
    save_button:SetCanResizeWidth(false)

    save_button:SetState("inactive")

    save_button:SetImagePath("ui/skins/default/icon_quick_save.png")
    save_button:SetTooltipText("Save||This will be enabled soon!", true)

    -- local addr = save_button:Address()

    -- core:add_listener(
    --     "mct_save_button",
    --     "ComponentLClickUp",
    --     function(context)
    --         return context.string == addr
    --     end,
    --     function(context)
    --         mct:finalize(true)
    --     end,
    --     true
    -- )
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
    left_panel:Resize(ew - xo* 0.5, eh)

    left_panel:SetImagePath("ui\\skins\\default\\parchment_divider_flush.png")

    local w,h = left_panel:Dimensions()

    -- make the stationary title (on left_panel_bg, doesn't scroll)
    local left_panel_title = core:get_or_create_component("left_panel_title", "ui/templates/parchment_divider_title", left_panel)
    left_panel_title:SetStateText(common.get_localised_string("mct_ui_mods_header"))
    left_panel_title:Resize(w, left_panel_title:Height())
    left_panel_title:SetDockingPoint(2)
    left_panel_title:SetDockOffset(0,0)

    local filter_holder = core:get_or_create_component("search_filter_holder", "ui/campaign ui/script_dummy", left_panel)
    filter_holder:Resize(w - 10, 68)
    filter_holder:SetDockingPoint(7)
    filter_holder:SetDockOffset(5, -5)

    local expand_collapse_button = core:get_or_create_component("button_expand_collapse_mct_mods", "ui/templates/square_small_toggle_plus_minus", left_panel)
    expand_collapse_button:SetDockingPoint(1)
    expand_collapse_button:SetDockOffset(5, left_panel_title:Height() + 5)
    expand_collapse_button:SetState("active")
    expand_collapse_button:SetTooltipText("Expand", true)

    local expand_collapse_txt = core:get_or_create_component("label", "ui/groovy/text/fe_default", expand_collapse_button)
    expand_collapse_txt:SetStateText("Expand All Rows")
    expand_collapse_txt:SetDockingPoint(6 + 9) -- center right External
    expand_collapse_txt:SetDockOffset(5, 0)
    expand_collapse_txt:Resize(left_panel_title:Width() * 0.6, expand_collapse_txt:Height())

    -- create listview
    local lview = core:get_or_create_component("list_view", "ui/groovy/layouts/listview", left_panel)
    lview:SetCanResizeWidth(true) lview:SetCanResizeHeight(true)
    lview:Resize(w, h-left_panel_title:Height() - expand_collapse_button:Height() - filter_holder:Height() - 15) 
    lview:SetDockingPoint(2)
    lview:SetDockOffset(0, left_panel_title:Height() + expand_collapse_button:Height() + 5)

    lview:SetCurrentStateImageOpacity(0, 0)

    local search_text = core:get_or_create_component("search_text", "ui/groovy/text/fe_default", filter_holder)
    search_text:Resize(filter_holder:Width() * 0.18, filter_holder:Height())
    local tw,th = search_text:TextDimensionsForText("Filter:")
    search_text:SetDockingPoint(4)
    search_text:SetDockOffset(0, 0)
    search_text:SetTextVAlign("centre")
    search_text:SetTextHAlign("left")
    search_text:SetStateText("Filter:")

    search_text:Resize(tw, th)

    local search_how_it_works = core:get_or_create_component("how_it_works_button", "ui/groovy/buttons/icon_button", search_text)
    search_how_it_works:SetDockingPoint(8)
    search_how_it_works:SetDockOffset(0, search_text:Height() * 0.5 + 12)
    search_how_it_works:SetImagePath("ui/skins/default/icon_question_mark.png", 0)
    search_how_it_works:SetTooltipText("Filter||Filter the mods by the text you provide in the box.\nThe filter will check mod titles, mod authors, and the titles of the pages within an individual mod. The currently selected mod is excluded from filter results!", true)

    local search_box = core:get_or_create_component("search_box", "ui/mct/search_text_box", filter_holder)
    search_box:Resize(filter_holder:Width() - search_text:Width() - 30, search_box:Height())
    search_box:SetDockingPoint(4)
    search_box:SetDockOffset(5 + search_text:Width(), 0)

    local clear_filter_button = core:get_or_create_component("button_mct_clear_filter", "ui/templates/square_small_button", search_box)
    clear_filter_button:SetImagePath("ui/skins/default/icon_cross_square.png", 0)
    clear_filter_button:SetDockingPoint(6 + 9)
    clear_filter_button:SetDockOffset(0, 0)
    clear_filter_button:SetTooltipText("Clear Filter", true)

    find_uicomponent(clear_filter_button, "icon"):SetVisible(false)

    local lclip = find_uicomponent(lview, "list_clip")
    local lbox = find_uicomponent(lclip, "list_box")

    -- save the listview and list box into the obj
    self.mod_row_list_view = lview
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
    right_panel:Resize(ew - (xo * 0.5), eh)
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

function UI_Main:apply_filter_to_mod_list()
    local search_box = find_uicomponent(self.left_panel, "search_filter_holder", "search_box")
    local search_str = search_box:GetStateText()

    -- if not is_string(search_str) then
    --     search_str = ""
    -- end

    -- loop through all mods and set their visibility based on search string.
    local mods = mct:get_mods()
    for mod_key, mod_obj in pairs(mods) do
        local main_row = mod_obj:get_row_uic()
        local mod_vis = mct:get_selected_mod_name() == mod_key -- if the mod is selected, then it's visible.
        local any_page_vis = false

        -- if the search string is empty, show all mods
        if search_str == "" then
            mod_vis = true
        else
            -- if the search string is not empty, check if the mod's title contains the search string
            local mod_title = mod_obj:get_title()
            local mod_author = mod_obj:get_author()

            if string.find(mod_title, search_str) then
                mod_vis = true
            end

            if string.find(mod_author, search_str) then
                mod_vis = true
            end

            -- search to see if the search string applies to any setting page title.
            local pages = mod_obj:get_settings_pages()

            for i, page in ipairs(pages) do
                local page_vis = mod_vis == true -- if the mod is visible, then all pages are visible. 
                local page_title = page:get_key()

                if not page_vis and string.find(page_title, search_str) then
                    any_page_vis = true
                    page_vis = true
                end

                local page_uic = page:get_row_uic()
                page_uic:SetVisible(page_vis)
            end

            if any_page_vis then mod_vis = true end
        end

        main_row:SetVisible(mod_vis)
    end
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
            if comp:Visible() == nil then
                core:remove_lookup_listener_callback("component_click_up", id)
                return
            end

            f()
        end,
        persistent
    )
end

--- TODO add MCT button to the Esc menu(?)
function UI_Main:create_mct_button(parent, x, y)
    local mct_button = core:get_or_create_component("button_mct", "ui/templates/round_small_button_toggle", parent)
    logf("Calling create_mct_button!")

    mct_button:SetImagePath(GLib.SkinImage("icon_options"))
    mct_button:SetTooltipText(common.get_localised_string("mct_mct_mod_title"), true)
    mct_button:SetVisible(true)

    if x and y then
        mct_button:MoveTo(x, y)
    else
        mct_button:SetDockingPoint(6)
        mct_button:SetDockOffset(mct_button:Width() * -2.8, 0)
    end

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
    "mct_clear_filter",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_clear_filter"
    end,
    function(context)
        local btn = UIComponent(context.component)
        -- parent is the text box.
        local parent = UIComponent(btn:Parent())
        parent:SetStateText("")

        UI_Main:apply_filter_to_mod_list()
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

core:add_listener(
    "mct_dropdown_box_option_selected",
    "ContextTriggerEvent",
    function(context)
        return context.string:starts_with("mct_mod_filter_changed")
    end,
    function(context)
        -- apply a filter to the mod list!
        UI_Main:apply_filter_to_mod_list()
    end,
    true
)

--- TODO move this into Command Manager
--- TODO hook this up more situationally
core:add_listener(
    "MCT_ContextCommands",
    "ContextTriggerEvent",
    function(context)
        return context.string:starts_with("mct_")
    end,
    function(context)
        local command_string = context.string
        local command_context = string.match(command_string, "([^|]-)|")
        local command_key = string.match(command_string, "|([^|]-)|")

        -- this isn't a context command we're tracking.
        if not command_context or not command_key then return end

        --- TODO multiple params, accept a table here
        local param = string.match(command_string, "|([^|]-)$")
        
        local this_context = GLib.CommandManager.commands[command_context]

        if this_context then

            local this_command = this_context[command_key]


            --- Figure out the context we need from the component!
            if command_context == "mct_mod_commands" then
                -- local mod_key = last_commponent:Call("ParentContext.ParentContext.ParentContext.ParentContext.ParentContext.GetProperty('mct_mod')")

                local mod_key = param
        
                --- TODO get the relevant properties from the component
                local mod_obj = mct:get_mod_by_key(mod_key)
                if mod_obj then
                    this_command.callback(mod_obj)
                end
            end
        end

    end,
    true
)

--- TODO hook up profiles!
core:add_listener(
    "mct_profiles_button_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_mct_profiles"
    end,
    function(context)
        -- ---@type MCT.UI.Profiles
        -- local UI_Profiles = mct:get_system_ui("profiles")
        -- UI_Profiles:open()
    end,
    true
)

--- TODO hook up profiles!
core:add_listener(
    "button_expand_collapse_mct_mods_pressed",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_expand_collapse_mct_mods"
    end,
    function(context)
        local all_mods = mct:get_mods()
        local button = UIComponent(context.component)
        local txt = find_uicomponent(button, "label")

        -- if active, we're expanding; else, we're collapsing
        local to_expand = txt:GetStateText() == "Expand All Rows"

        local selected = mct:get_selected_mod()

        for key,obj in pairs(all_mods) do
            if obj == selected then
                -- ignore the selected mod
            else
                obj:toggle_subrows(to_expand)
            end
        end

        -- toggle the button
        if to_expand then
            button:SetState("selected")
            txt:SetStateText("Collapse All Rows")
        else
            button:SetState("active")
            txt:SetStateText("Expand All Rows")
        end
    end,
    true
)


core:add_listener(
    "mct_mod_toggle_subrows",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_open_close" and UIComponent(context.component):GetProperty("mct_mod") ~= ""
    end,
    function(context)
        local uic = UIComponent(context.component)
        local mod_key = uic:GetProperty("mct_mod")

        local mod_obj = mct:get_mod_by_key(mod_key)
        mod_obj:toggle_subrows()
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

return UI_Main