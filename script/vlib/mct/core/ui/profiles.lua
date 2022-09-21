--- TODO a separate UI object with just all the Profiles systems in them

local mct = get_mct()
local Registry = mct.registry
local UI_Main = mct.ui

---@class MCT.UI.Profiles
local defaults = {
    ---@type UIC? The currently selected Profile holder.
    selected_holder = nil,

    --- TODO do I need this?
    selected_profile = "",

    ---@type table<string, UIC>
    uics = {},
}

---@class MCT.UI.Profiles : Class
local UI_Profiles = VLib.NewClass("UI_Profiles", defaults)

function UI_Profiles:open()
    local profiles_popup = core:get_or_create_component("profiles_popup", "ui/vandy_lib/popups/pretty_popup", UI_Main.panel)
    profiles_popup:PropagatePriority(UI_Main.panel:Priority() + 100)
    profiles_popup:LockPriority()
    profiles_popup:Resize(UI_Main.panel:Width() * 0.9, UI_Main.panel:Height() * 0.8)

    --- TODO set this using a prettier component
    local title = core:get_or_create_component("title", "ui/vandy_lib/text/paragraph_header", profiles_popup)
    title:SetStateText("Profiles")
    title:SetTooltipText("[PH] Text!", true)
    title:SetDockingPoint(11)
    title:SetDockOffset(0, title:Height() * 1.2)

    self.uics.profiles_popup = profiles_popup
    self.uics.title = title

    self:create_main_view()
    self:create_settings_view()

    self:populate_main_view()

    core:add_listener(
        "MCT_ProfilePopupClose",
        "ComponentLClickUp",
        function(context)
            return context.string == "button_close" and uicomponent_descended_from(UIComponent(context.component), profiles_popup:Id())
        end,
        function(context)
            ModLog("Closing MCT_ProfilePopup")
            self:close()
        end,
        false
    )
end

function UI_Profiles:close()
    ModLog("Calling UI_Profiles:close()")
    core:remove_listener("MCT_ProfilePopup")
    self.uics.profiles_popup:Destroy()

    self.uics = {}
    self.selected_holder = nil
    self.selected_profile = ""

    Registry:save_profiles_file()
end

function UI_Profiles:set_selected_profile(profile_button)
    -- get our new selected buttons
    local frame = find_uicomponent(profile_button, "frame")
    local profile_holder = UIComponent(profile_button:Parent())
    local button_expand_profile = find_uicomponent(profile_holder, "button_expand_profile")

    local this_profile = Registry:get_profile(profile_holder:GetProperty("mct_profile"))
    
    
    -- set profile as selected
    profile_button:SetState("selected")
    frame:SetState("selected")
    
    -- visible the expand button 
    button_expand_profile:SetVisible(true)
    
    -- change the details panel
    self.uics.profile_name:SetStateText(this_profile:get_name())
    self.uics.profile_desc:SetStateText(this_profile:get_description())
    
    self.selected_profile = this_profile:get_name()
    self.selected_holder = profile_holder
end

---@param profile_button UIC New profile button pressed
function UI_Profiles:change_selected_profile(profile_button)
    if is_uicomponent(self.selected_holder) then
        -- do nothing if it's the same button
        if self.selected_holder == UIComponent(profile_button:Parent()) then return end
        
        -- deselect previous button
        local button = find_uicomponent(self.selected_holder, "profile_button")
        local frame = find_uicomponent(button, "frame")

        local button_expand_profile = find_uicomponent(self.selected_holder, "button_expand_profile")

        button:SetState("active")
        frame:SetState("active")
        button_expand_profile:SetVisible(false)
    end

    self:set_selected_profile(profile_button)
end

function UI_Profiles:create_profile_popup()
    local create_profile_popup = core:get_or_create_component("create_profile_popup", "ui/vandy_lib/popups/text_input", self.uics.profiles_popup)

    local title = find_uicomponent(create_profile_popup, "panel_title")
    local tx = find_uicomponent(title, "heading_txt")
    tx:SetStateText("Create New Profile")

    --- TODO a text input for name
    local text_input = find_uicomponent(create_profile_popup, "text_input_list_parent", "text_input")
    text_input:SetStateText("Profile Name")

    --- TODO error checking, grey out the buttons, add a tooltip to the buttons when bad, etc.

    local curr_text = text_input:GetStateText()

    core:get_tm():repeat_real_callback(function()
        ModLog("In MCT_CreateProfilePopup real timer")
        local uic = find_uicomponent("create_profile_popup")
        if is_uicomponent(uic) then
            curr_text = text_input:GetStateText()
        else
            ModLog("\tNo longer valid, destroying.")
            core:get_tm():remove_real_callback("MCT_CreateProfilePopup")
        end
        --- TODO error check
    end, 10, "MCT_CreateProfilePopup")

    core:add_listener(
        "MCT_CreateProfilePopup",
        "ComponentLClickUp",
        function(context)
            return (context.string == "button_ok" or context.string == "button_cancel")
        end,
        function(context)
            ModLog("MCT_CreateProfilePopup")
            core:get_tm():remove_real_callback("MCT_CreateProfilePopup")
            local id = context.string

            if id == "button_ok" then
                ModLog("Button ok pressed!")
                -- Create a new profile!
                Registry:new_profile(text_input:GetStateText())

                ModLog("New profile made!")

                local ok, err = pcall(function()
                    ModLog("Pressed OK on our new Profile name, repopulating the holder!")
                self:populate_profiles_holder()
                end) if not ok then ModLog(err) end
            end

            create_profile_popup:Destroy()
        end,
        false
    )
end


function UI_Profiles:create_settings_view()
    local profiles_popup = self.uics.profiles_popup
    local title = self.uics.title

    local settings_view = core:get_or_create_component("settings_view", "ui/campaign ui/script_dummy", profiles_popup)
    settings_view:Resize(profiles_popup:Width(), profiles_popup:Height())
    settings_view:SetVisible(false)
    settings_view:SetDockingPoint(5)
    settings_view:SetDockOffset(0, 0)


    self.uics.settings_view = settings_view

    --- create the currently selected profile element on the top left
    local topleft_holder = core:get_or_create_component("topleft_holder", "ui/vandy_lib/layouts/hlist_four", settings_view)
    topleft_holder:SetDockingPoint(1)
    topleft_holder:SetDockOffset(15, 30)
    topleft_holder:Resize(settings_view:Width() * 0.35, title:Height())

    --- TODO back button
    local back_button = core:get_or_create_component("button_return", "ui/templates/round_medium_button", topleft_holder)
    back_button:SetImagePath("ui/skins/default/icon_home.png")
    back_button:SetTooltipText("Return", true)
    back_button:SetDockOffset(0, -10)

    --- current profile name (just the button from the previous screen?)
    local current_profile = core:get_or_create_component("current_profile", "ui/mct/pretty_button", topleft_holder)
    
    current_profile:SetState("selected")
    find_uicomponent(current_profile, "frame"):SetState("selected")
    current_profile:SetInteractive(false)
    



    --- TODO rename button
    --- TODO delete button
    --- TODO create the button holder & all buttons
    local buttons_holder = core:get_or_create_component("buttons_holder", "ui/vandy_lib/layouts/hlist_four", settings_view)
    buttons_holder:SetDockingPoint(3)
    buttons_holder:SetDockOffset(-15, 15)
    buttons_holder:Resize(settings_view:Width() * 0.35, title:Height())

    --- TODO a title for this section saying "OVerrides" and a lil tooltip explaining how it works.
    --- TODO the bottom layout engine for the overridden settings
    -- local settings_holder = core:get_or_create_component("settings_holder", "ui/")
    --- TODO create the settings holders in the bottomssssssssssssssssssssssssssss
end

--- TODO export button here
function UI_Profiles:create_main_view()
    local profiles_popup = self.uics.profiles_popup
    local title = self.uics.title

    local main_view = core:get_or_create_component("main_view", "ui/campaign ui/script_dummy", profiles_popup)
    main_view:Resize(profiles_popup:Width(), profiles_popup:Height())
    main_view:SetVisible(true)
    main_view:SetDockingPoint(5)
    main_view:SetDockOffset(0, 0)


    local buttons_holder = core:get_or_create_component("buttons_holder", "ui/vandy_lib/layouts/hlist_four", main_view)
    buttons_holder:SetDockingPoint(1)
    buttons_holder:SetDockOffset(15, 15)
    buttons_holder:Resize(main_view:Width() * 0.35, title:Height())

    local new = core:get_or_create_component("button_create_profile", "ui/templates/square_small_button", buttons_holder)
    new:SetTooltipText("Create new profile", true)
    find_uicomponent(new,"icon"):SetVisible(false)
    new:SetImagePath("ui/skins/default/icon_plus_small.png")
    
    local import = core:get_or_create_component("button_import_profile", "ui/templates/square_small_button", buttons_holder)
    import:SetTooltipText("Import a Profile", true)
    find_uicomponent(import,"icon"):SetVisible(false)
    import:SetImagePath("ui/skins/default/icon_load.png")
    
    local profiles_holder = core:get_or_create_component("profiles_holder", "ui/vandy_lib/layouts/hlist_three", main_view)
    profiles_holder:Resize(main_view:Width() * 0.96, main_view:Height() * 0.3)
    profiles_holder:SetDockingPoint(2)
    profiles_holder:SetDockOffset(0, title:Height() * 2 + 10)

    self.uics.profiles_holder = profiles_holder

    self:populate_profiles_holder()

    --- create the bottom half of the page, use the cutesy background block thing with a frame and add buttons and all loads of shit mayn
    local bottom = core:get_or_create_component("details_holder", "ui/vandy_lib/image", main_view)
    bottom:SetDockingPoint(8)
    bottom:SetDockOffset(0, -15)
    bottom:Resize(main_view:Width() * 0.90, main_view:Height() - profiles_holder:Height() - title:Height() - 200)
    bottom:SetImagePath("ui/skins/default/parchment_divider.png")
    bottom:SetCurrentStateImageTiled(0, true)
    bottom:SetCurrentStateImageMargins(0, 30, 30, 15, 30)

    local profile_name = core:get_or_create_component("profile_name", "ui/vandy_lib/text/paragraph_header", bottom)
    profile_name:SetDockingPoint(2)
    profile_name:SetDockOffset(0, 15)
    profile_name:SetStateText("Selected Profile")

    local hdiv = core:get_or_create_component("divider", "ui/vandy_lib/image", bottom)
    hdiv:SetDockingPoint(2+9)
    hdiv:SetDockOffset(0, 10)
    hdiv:Resize(main_view:Width() * 0.98, 13)
    hdiv:SetImagePath("ui/skins/default/parchment_divider_length.png")
    hdiv:SetCurrentStateImageTiled(0, true)
    hdiv:SetCurrentStateImageMargins(0, 2, 0, 2, 0)
    
    local profile_desc = core:get_or_create_component("profile_desc", "ui/vandy_lib/text/dev_ui", bottom)
    profile_desc:SetDockingPoint(2)
    profile_desc:SetDockOffset(0, 30 + profile_name:Height())
    profile_desc:SetStateText("")
    -- profile_desc:SetVisible(false)

    self.uics.profiles_popup = profiles_popup
    self.uics.main_view = main_view
    self.uics.profile_name = profile_name
    self.uics.profile_desc = profile_desc
end

function UI_Profiles:populate_main_view()
    self.uics.main_view:SetVisible(true)
    self.uics.settings_view:SetVisible(false)

    self:populate_profiles_holder()

    core:remove_listener("MCT_ProfilePopupMainView")
    core:remove_listener("MCT_ProfilePopupSettingsView")

    core:add_listener(
        "MCT_ProfilePopupMainView",
        "ComponentLClickUp",
        function(context)
            return context.string == "profile_button" and is_string(UIComponent(context.component):GetProperty("mct_profile"))
        end,
        function(context)
            local button = UIComponent(context.component)
            self:change_selected_profile(button)
        end,
        true
    )

    core:add_listener(
        "MCT_ProfilePopupMainView",
        "ComponentLClickUp",
        function(context)
            return context.string ~= "button_close" and uicomponent_descended_from(UIComponent(context.component), "main_view")
        end,
        function(context)
            local pressed = UIComponent(context.component)
            if context.string == "button_create_profile" then
                self:create_profile_popup()
            end

            if context.string == "button_expand_profile" then
                local profile_key = pressed:GetProperty("mct_profile")
                self:populate_settings_view(Registry:get_profile(profile_key))
            end
        end,
        true
    )
end

---@param profile MCT.Profile 
function UI_Profiles:populate_settings_view(profile)
    self.uics.main_view:SetVisible(false)
    self.uics.settings_view:SetVisible(true)
    
    local profiles_button = find_uicomponent(self.uics.settings_view, "topleft_holder", "current_profile")
    local label = find_uicomponent(profiles_button, "label")
    label:SetStateText(profile:get_name())


    core:remove_listener("MCT_ProfilePopupMainView")
    core:remove_listener("MCT_ProfilePopupSettingsView")
    core:add_listener(
        "MCT_ProfilePopupReturn",
        "ComponentLClickUp",
        function(context)
            return context.string == "button_return" and uicomponent_descended_from(UIComponent(context.component), "settings_view")
        end,
        function(context)
            self:populate_main_view()
        end,
        false
    )
end

function UI_Profiles:populate_profiles_holder()
    ModLog("Populating!")
    local profiles_holder = self.uics.profiles_holder

    local none = true
    for profile_key, profile_obj in pairs(Registry:get_profiles()) do
        ModLog("In our first profile!")
        none = false
        --- TODO profile_holder is a vlist that holds both the button and the other button
        local profile_holder = core:get_or_create_component("profile_"..profile_key.."_holder", "ui/mct/layouts/resize_column", profiles_holder)
        profile_holder:SetProperty("mct_profile", profile_key)
    
        local profile_button = core:get_or_create_component("profile_button", "ui/mct/pretty_button", profile_holder)
        profile_button:Resize(profile_button:Width() * 0.8, profile_button:Height())
        profile_button:SetProperty("mct_profile", profile_key)
        
        find_uicomponent(profile_button, "label"):SetStateText(profile_obj:get_name())
        
        local button_expand_profile = core:get_or_create_component("button_expand_profile", "ui/templates/square_medium_text_button", profile_holder)
        button_expand_profile:SetDockingPoint(8+9)
        button_expand_profile:SetDockOffset(0, 5)
        button_expand_profile:SetProperty("mct_profile", profile_key)
    
        find_uicomponent(button_expand_profile, "button_txt"):SetStateText("Expand or some shit")
    
        button_expand_profile:SetVisible(false)
        profile_button:SetState("active")

        if self.selected_profile and self.selected_profile == profile_key then
            self:set_selected_profile(profile_button)
        end
    end

    ModLog("Creating no profiles text")
    
    local no_profiles = core:get_or_create_component("no_profiles_txt", "ui/vandy_lib/text/dev_ui", profiles_holder)
    no_profiles:SetVisible(none)
    no_profiles:Resize(300, 35)
    no_profiles:SetStateText("No profiles available!")
    no_profiles:SetTextHAlign("centre")
end

return UI_Profiles