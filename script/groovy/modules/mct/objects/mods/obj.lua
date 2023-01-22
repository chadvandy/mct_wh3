--- The mct_mod object.
--- This holds all of the details for one mod - name, author, available options, UI appearances, etc.
--- @class MCT.Mod


local mct = get_mct()

local log,logf,err,errf = get_vlog("[mct]")

--- the table.
---@class MCT.Mod
local mct_mod_defaults = {
    ---@type string The key for this mod object.
    _key = "",

    ---@type table The patches created for this mod - the various patches and the relative dates and info. Highest index is the most recent, first index is the first one made.
    _patches = {},

    ---@type number The last patch num viewed by the current user. Saved by MCT.
    _last_viewed_patch = 0,

    ---@type table<string, MCT.Option>
    _options = {},

    _options_by_type = mct:get_valid_option_types_table(),

    _options_by_index_order = {},

    _coords = {},

    _finalized_settings = {},

    _sections = {},

    --- Used to store the path to a log file, for the internal MCT logging functionality.
    _log_file_path = nil,

    _title = "No Title Assigned",
    _author = "No Author Assigned",
    _description = "No Description Assigned",

    ---@type string The tooltip text for this mod, shown on the row header.
    _tooltip_text = "",

    ---@type string The ID for this mod.
    _workshop_id = "",

    ---@type string The GitHub ID for this mod. Should be the username/repo format.
    _github_id = "",

    ---@type table<string, MCT.Page> All of the Pages defined for this mod.
    _pages = {},

    ---@type table<number, MCT.Page.Settings> All of the settings pages defined for this mod.
    _settings_pages = {},

    ---@type MCT.Page.Main the Main page for this mod, the one that will open on pressing the mod header.
    _main_page = nil,

    _page_uics = {},

    ---@type UIC The row header for this mod's main page
    _row_uic = nil,

    ---@type table<string, any> Persistent userdata table that gets saved in Registry.
    _userdata = {},

    ---@type string The current version number of this mod. Used for Notifications, Changelogs, etc.
    _version = "",

    ---@type {path:string, width:number, height:number} The info of a main image for this mod, to display where relevant. Optional w/h overrides (they may be clamped lower, but aspect ratio defined here will be kept!) 
    _main_image = {path = "", width = 100, height = 100,},

    ---@type boolean Whether or not this mod is enabled. If false, the mod will not be loaded.
    __bIsDisabled = false,

    ---@type string The reason this mod is disabled.
    __strDisabled = "",

    ---@type boolean Whether or not the mod's subrows are open. If true, the mod's subrows are visible.
    __bRowsOpen = false,

    ---@type table<string, UIC> The UI components for this mod.
    __uics = {},

    _main_page_tabs = {},
}

---@class MCT.Mod : Class
---@field __new fun():MCT.Mod
local mct_mod = GLib.NewClass("MCT_Mod", mct_mod_defaults)

--- For internal use, called by the MCT Manager. Creates a new mct_mod object.
---@param key string The key for the new mct_mod. Has to be unique!
---@return MCT.Mod
---@see mct:register_mod
function mct_mod:new(key)
    local o = mct_mod:__new()
    assert(mct:verify_key(o, key))

    -- Create the default Settings page, that can be disabled by the Moddeur if desired.
    local S = o:create_settings_page("Settings", 2)

    return o
end

---@return MCT.Page.Main
function mct_mod:get_main_page()
    if not self._main_page then
        -- self:set_main_page(self:create_settings_page("settings", 2))
        self:create_main_page()
    end

    return self._main_page
end

--- TODO automatically create the main page built off of a "Main Page" layout.
function mct_mod:create_main_page()
    local Page = get_mct():get_mct_page_type("main")
    ---@cast Page MCT.Page.Main
    Page = Page:new(self)
    
    ---@cast Page MCT.Page.Main
    -- Page:set_title("Main Page")
    -- Page:set_description("This is the main page for this mod. It's automatically generated, and can be edited in the mod's layout file.")

    self._main_page = Page
end

---@return MCT.Page.Settings
function mct_mod:create_settings_page(title, num_columns)
    local PageClass = mct:get_mct_page_type("settings")
    ---@cast PageClass MCT.Page.Settings
    local Page = PageClass:new(title, self, num_columns)

    self._settings_pages[#self._settings_pages+1] = Page

    return Page
end

function mct_mod:get_settings_pages()
    return self._settings_pages
end

function mct_mod:get_first_settings_page()
    return self._settings_pages[1]
end

function mct_mod:get_settings_page_with_key(key)
    for i, page in pairs(self._settings_pages) do
        if page:get_key() == key then
            return page
        end
    end

    -- if none found, return a default page?
end

function mct_mod:set_disabled(b, strReason)
    if not is_boolean(b) then b = true end

    if b == true and not is_string(strReason) then
        strReason = "No reason given."
    end

    self.__bIsDisabled = b
    self.__strDisabled = strReason
end

---@return boolean
function mct_mod:is_disabled()
    return self.__bIsDisabled
end

---@return string
function mct_mod:get_disabled_reason()
    return self.__strDisabled
end

---@param page MCT.Page.Settings
function mct_mod:set_main_page(page)
    -- logf("Setting main page of %s to %s", self:get_key(), page:get_key())
    -- self._main_page = page
end

function mct_mod:set_version(version_num)
    assert(is_string(version_num), string.format("Version [%s] for mod %s is not a string!", tostring(version_num), self:get_key()))

    self._version = version_num
end

---@return string
function mct_mod:get_version()
    return self._version
end

function mct_mod:set_main_image(path, w, h)
    if not is_string(path) then return false end

    self._main_image.path = path
    if is_number(w) then self._main_image.width = w end
    if is_number(h) then self._main_image.height = h end
end

function mct_mod:get_main_image()
    return self._main_image.path, self._main_image.width, self._main_image.height
end

function mct_mod:use_infobox(b)
    -- if is_nil(b) then b = true end
    -- if not is_boolean(b) then return end

    -- if b == true then
    --     local page_class = mct:get_mct_page_type("infobox")
    --     ---@cast page_class MCT.Page.Infobox
    --     local page = page_class:new("Details", self)
        
    --     ---@cast page MCT.Page.Infobox
    --     self._pages["Details"] = page
        
    --     return page
    -- else
    --     self._pages["Details"] = nil
    -- end
end

-- function mct_mod:create_rowbased_settings_page(title)
--     local page_class = mct:get_page_type("settings")
--     ---@cast page_class MCT.Page.Settings
--     local page = page_class:new(title, self, 1, true)
    
--     ---@cast page MCT.Page.Settings
--     self._pages[title] = page

--     return page
-- end

--- Create a new MCT Page that's a blank canvas to draw whatever on.
---@param key string The key for this Page, to get it later.
---@param creation_callback fun(UIC) The creation function run when the Canvas is populated.
---@return MCT.Page.Canvas
function mct_mod:create_canvas_page(key, creation_callback)
    local page_class = mct:get_mct_page_type("canvas")
    ---@cast page_class MCT.Page.Canvas
    local page = page_class:new(key, self, creation_callback)

    self._pages[key] = page

    return page
end

--- Getter for any @{mct_section}s linked to this mct_mod.
---@param section_key string The identifier for the section searched for.
---@return MCT.Section
function mct_mod:get_section_by_key(section_key)
    if not is_string(section_key) then
        err("get_section_by_key() called on mct_mod ["..self:get_key().."], but the section_key supplied is not a string! Returning the last section.")
        return self:get_last_section()
    end

    local t = self._sections[section_key]
    if not mct:is_mct_section(t) then
        err("get_section_by_key() called on mct_mod ["..self:get_key().."], but the section found in self._sections is not an mct_section! Returning the last available section.")
        return self:get_last_section()
    end

    return t
end

--- TODO wrapper, get the page key and then get its assigned sections
function mct_mod:get_sections_by_page(page)

end

--- Add a new section to the mod's settings view, to separate them into several categories.
-- When this function is called, it assumes all following options being defined are being assigned to this section, unless further specified with
-- mct_option.
--- @param section_key string The unique identifier for this section.
--- @param localised_name string? The localised text for this section. You can provide a direct string - "My Section Name" - or a loc key - "`loc_key_example_my_sect ion_name`". If a loc key is provided, it will check first at runtime to see if that localised text exists. If no localised_name is provided, it will default to "No Text Assigned". Can leave this and the other blank, and use @{mct_section:set_localised_text} instead.
--- @return MCT.Section # Returns the mct_section object created from this call.
function mct_mod:add_new_section(section_key, localised_name)
    if not is_string(section_key) then
        err("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the section_key supplied was not a string! Returning false.")
        ---@diagnostic disable-next-line
        return nil
    end

    if not is_string(localised_name) then
        localised_name = ""
        --err("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the localised_name supplied was not a string! Returning false.")
        --return false
    end

    local new_section = mct:get_mct_section_class().new(section_key, self)

    if localised_name ~= "" then
        new_section:set_localised_text(localised_name)
    end

    self._sections[section_key] = new_section
    self._last_section = new_section

    new_section:assign_to_page(self:get_first_settings_page())

    return new_section
end

--- Returns a k/v table of `{option_key=option_obj}` for options that are linked to this section.
-- Shouldn't need to be used externally.
---@param section_key string The unique identifier for this section.
---@return table<string, MCT.Option>
function mct_mod:get_options_by_section(section_key)
    if not is_string(section_key) then
        err("get_options_by_section() called on mct_mod with key ["..self:get_key().."], but the section_key provided was not a string! Returning an empty table.")
        return {}
    end

    local section = self:get_section_by_key(section_key)

    if is_nil(section) then
        err("get_options_by_section() called on mct_mod with key ["..self:get_key().."], but there was no section found with the key ["..section_key.."]. Returning an empty table.")
        return {}
    end

    return section:get_options()

    --[[local options = self:get_options()
    local retval = {}
    for option_key, option_obj in pairs(options) do
        if option_obj:get_assigned_section() == section_key then
            retval[option_key] = option_obj
        end
    end

    return retval]]
    --return self._options_by_section[section_key]
end

--- Returns a table of all "sections" within the mct_mod.
-- These are returned as an array of tables, and each table has two indexes - ["key"] and ["txt"], for internal key and localised name, in that order.
---@return table<string, MCT.Section>
function mct_mod:get_sections()
    return self._sections
end

--- Set the log file path, relative to the Warhammer2.exe folder.
-- Used for the logging tab. If nothing is set, the logging tab will be locked.
---@param path string The path to the log file. Include the file extension!
function mct_mod:set_log_file_path(path)
    if not is_string(path) then
        err("set_log_file_path() called for mct_mod with key ["..self:get_key().."], but the path provided is not a string!")
        return false
    end

    local file = io.open(path, "r+")
    -- should this return or just do a warning?
    if not file then
        log("set_log_file_path() called for mct_mod with key ["..self:get_key().."], but no file with the name ["..path.."] exists on disk!")
    else
        -- don't hold it hostage anymore
        file:close()
    end

    self._log_file_path = path
end

--- Getter for the log file path.
-- @return string
function mct_mod:get_log_file_path()
    return self._log_file_path
end

--- Set the rows of a section visible or invisible.
---@param section_key string The unique identifier for the desired section.
---@param visible boolean Set the rows visible (true) or invisible (false)
function mct_mod:set_section_visibility(section_key, visible)
    if not is_string(section_key) then
        err("set_section_visibility() called for mct_mod with key ["..self:get_key().."], but the section_key provided is not a string!")
        return false
    end

    if is_nil(visible) then visible = true end
    
    if not is_boolean(visible) then
        err("set_section_visibility() called for mct_mod with key ["..self:get_key().."], but the visible arg provided is not a boolean or nil!")
        return false
    end

    local section = self:get_section_by_key(section_key)
    if is_nil(section) then
        err("set_section_visibility() called for mct_mod ["..self:get_key().."] for section with key ["..section_key.."], but no section with that key exists!")
        return false
    end

    section:set_visibility(visible)

    --mct:get_ui():section_visibility_change(section_key, visible)
end

--- Internal use only, no real need for use anywhere else.
-- Specifically used when creating new options, to find the last-made section.
-- @local
function mct_mod:get_last_section()
    if not self._last_section then
        -- start with a default section, if none are created by the Modder.
        self:add_new_section("default", "mct_mct_mod_default_section_text")
    end

    -- return the last created section
    return self._last_section
end

--- Getter for the mct_mod's key
---@return string key The key for this mct_mod
function mct_mod:get_key()
    return self._key
end


--- TEMP for backwards compat
function mct_mod:set_section_sort_function(sort_func)
    for k,v in pairs(self._pages) do
        if v.className == "Settings" then
            ---@cast v MCT.Page.Settings
            v:set_section_sort_function(sort_func)
        end
    end
end

--- TODO global table sanitizer

function mct_mod:set_userdata(t)
    if not is_table(t) then return end

    --- TODO sanitize this table
    self._userdata = t
end

---@param as_table boolean? #If we want the Lua table instead of the sanitized printed string.
---@return string|table
function mct_mod:get_userdata(as_table)
    if as_table then return self._userdata end

    return table_printer:print(self._userdata)
end

function mct_mod:set_userdata_kv(k, v)
    if not is_table(self._userdata) then self._userdata = {} end

    --- Can only save string or number indices!
    if not is_string(k) and not is_number(k) then return end
    if is_table(v) then
        --- TODO handle tables
    else
        --- Can only handle string/number/boolean values
        if not is_string(v) and not is_number(v) and not is_boolean(v) then
            return
        end
    end

    self._userdata[k] = v
end

--- Set the option-sort-function for every section
--- Triggers @{mct_section:set_option_sort_function} for every section.
--- If you want to make 6 sections with "key_sort", and a 7th with "index_sort", use this first after making all sections and then use @{mct_section:set_option_sort_function} on the 7th afterwards.
---@param sort_func any See the wrapped function for what this argument needs to be.
function mct_mod:set_option_sort_function_for_all_sections(sort_func)
    local sections = self:get_sections()

    -- error checking is performed in each individual section object
    for _, section_obj in pairs(sections) do
        section_obj:set_option_sort_function(sort_func)
    end
end

--- The finalize function is used for all actions needed to be performmed when the `mct_mod` is done being created, like setting positions for all options.
--- Triggered once the file which housed this `mod_obj` is done loading
--- @local
function mct_mod:finalize()
    -- disable mp-disabled options in mp
    if __game_mode == __lib_type_campaign and cm.game_interface:model():is_multiplayer() then
        local options = self:get_options()

        for key, option_obj in pairs(options) do
            if option_obj:get_mp_disabled() == true then
                -- literally just remove it
                self:delete_option(key)
            end
        end
    end

    core:trigger_custom_event("MctModCreated", {mct = mct, mod = self})
end

--- TODO clean this up?
--- Loops through all sections, and checks all options within each section, to save the x/y coordinates of each option.
--- Order the options by key within each section, giving sliders a full row to their own self
--- @local
function mct_mod:set_positions_for_options()
    local sections = self:get_sections()

    -- log("setting positions for options in mod ["..self:get_key().."]")
    
    for section_key, section_obj in pairs(sections) do
        -- log("in section ["..section_key.."].")

        local ordered_option_keys = section_obj:sort_options()
        section_obj._true_ordered_options = {}

        local total = #ordered_option_keys

        -- log("total num = " .. tostring(total))

        local x = 1
        local y = 1

        -- only put sliders on x == 2

        local valid = true
        local j = 1
        local any_added_on_current_row = false
        local slider_added_on_current_row = false

        -- TODO disabled for now with the new sliders
        local function valid_for_type(type, x,y)
            -- hard check for sliders, must be in center and can't have any other options on the same row
            --[[if type == "slider" then
                if x == 2 and not any_added_on_current_row then return true end
                return false
            end

            -- only sliders!
            if slider_added_on_current_row then
                return false
            end]]
            
            -- everything else is fine (for now!!!!!!)
            return true
        end

        --log("down here now")

        local function iterate(added)
            if x == 3 then
                x = 1
                y = y + 1

                -- new row, set to false
                any_added_on_current_row = false
                slider_added_on_current_row = false
            else
                x = x + 1

                -- same row
                if added then
                    any_added_on_current_row = true
                end
            end
            if added then j = j + 1 end
        end

        --log("about to loop!")

        while valid do
            if j > total then
                break
            end

            --log("in the loop")
            --log("iteration #"..tostring(j))

            local option_key = ordered_option_keys[j]
            local option_obj = self:get_option_by_key(option_key)

            --log("at key "..option_key)

            if option_obj and mct:is_mct_option(option_obj) then        
                --log("it's valid")        
                -- check if it's a valid position for that option's type (sliders only on 2)
                if valid_for_type(option_obj:get_type(), x, y) then
                    if option_obj:get_type() == "slider" then slider_added_on_current_row = true end
                    --log("setting pos for ["..option_key.."] at ("..tostring(x)..", "..tostring(y)..").")
                    option_obj:override_position(x,y)

                    section_obj:set_option_at_index(option_key, x, y)

                    iterate(true)

                    --j = j + 1
                else
                    -- if the current one is invalid, we should check the next few options to see if any are valid.
                    local done = false

                    iterate(done)
                end
            else
                -- not a valid MCT option
                -- could be MP disabled, could've been deleted - just skip it and call it a day!
                iterate(true)
            end
        end
    end
end

--- Set all options to their default value in the UI
function mct_mod:revert_to_defaults()
    --log("Reverting to defaults for mod ["..self:get_key().."]")
    local all_options = self:get_options()

    for _, option_obj in pairs(all_options) do
        local current_val = option_obj:get_selected_setting()
        local default_val = option_obj:get_default_value(true)

        if not is_nil(default_val) and current_val ~= default_val then
            option_obj:set_selected_setting(default_val)
            --option_obj:ui_select_value(default_val)
        else
            --log("currently on default value")
        end
    end
end

--- Check if any selected settings are not default!
function mct_mod:are_any_settings_not_default()
    local all_options = self:get_options()

    for option_key, option_obj in pairs(all_options) do
        local current_val = option_obj:get_selected_setting()
        local default_val = option_obj:get_default_value()

        if current_val ~= default_val then
            return true
        end
    end

    return false
end

--- TODO re-implement this through Pages
--- Create a new patch. This allows you to slightly-better communicate with your users, by adding patches to a tab within the UI and potentially forcing a popup to inform your users of important stuff.
---@param patch_name string The name of your patch. Will display in larger text in the patch notes section.
---@param patch_description string Description for your patch. Accepts any existing localisation tags - [[col]] tags or whatever. Will get automatic linebreaks in it, to make it fit properly.
---@param patch_number number The order this patch should come in. Don't skip any numbers, and keep these to whole integers - ie., 1-2-3-4-5. Higher number means more recent, which means a higher placement; put your oldest at 1 and your highest at max.
---@param is_important boolean Set this to true to prioritize this patch by giving a popup to the user about a new patch (will only show once). Don't abuse pls!
function mct_mod:create_patch(patch_name, patch_description, patch_number, is_important)
    assert(is_string(patch_name), "You need to provide a patch name for the patch!")
    assert(is_string(patch_description), "You need to provide a patch description!")
    
    -- TODO somee way to make sure the number is valid?
    if not is_number(patch_number) then patch_number = #self._patches+1 end
    if not is_boolean(is_important) then is_important = false end

    patch_description = string.format_with_linebreaks(patch_description, 150)


    self._patches[patch_number] = 
    {
        name = patch_name,
        description = patch_description,
        is_important = is_important
    }

    core:trigger_custom_event(
        "MctPatchCreated", 
        {
            mct = mct,
            mod = self,
            patch = self._patches[patch_number],
            patch_number = patch_number,
        }
    )
end

function mct_mod:set_last_viewed_patch(index)
    if not is_number(index) or not self._patches[index] then return end

    self._last_viewed_patch = index
end

function mct_mod:get_last_viewed_patch()
    return self._last_viewed_patch
end

function mct_mod:get_patches()
    return self._patches
end

function mct_mod:get_patch(index)
    return self._patches[index]
end

function mct_mod:get_settings_table()

end

function mct_mod:load_finalized_settings()
    local options = self:get_options()

    local ret = {}
    for key, option in pairs(options) do
        ret[key] = {}

        -- only trigger the option-changed event if it's actually changing setting
        local selected = option:get_selected_setting()
        if option:get_finalized_setting() ~= selected then
            option:set_finalized_setting(selected)
        end

        ret[key] = option:get_finalized_setting()
    end

    self._finalized_settings = ret
end

--- Returns a k/v table of all option keys and their currently finalized setting.
function mct_mod:get_settings()
    local options = self:get_options()
    local retval = {}

    for key, option in pairs(options) do
        retval[key] = option:get_selected_setting()
    end

    return retval
end

function mct_mod:get_settings_by_section(section_key)
    local retval = {}

    if not self:get_section_by_key(section_key) then
        GLib.Error("Trying to get settings within section %s of mod %s, but there is no section with that name!", section_key, self:get_key())
        return retval
    end

    local options = self:get_options_by_section(section_key)
    for key,option in pairs(options) do
        retval[key] = option:get_finalized_setting()
    end

    return retval
end

--- Enable localisation for this mod's title. Accepts either finalized text, or a localisation key.
---@param title_text string The text supplied for the title. You can supply the text - ie., "My Mod", or a loc-key, ie. "ui_text_replacements_my_dope_mod". Please note you can also skip this method, and just make a loc key called: `mct_[mct_mod_key]_title`, and MCT will automatically read that.
function mct_mod:set_title(title_text)
    if is_string(title_text) then
        self._title = title_text
    end
end

--- Set the Author text for this mod.
---@param author_text string The text supplied for the author. Doesn't accept loc-keys. Please note you can skip this method, and just make a loc key called: `mct_[mct_mod_key]_author`, and MCT will automatically read that.
function mct_mod:set_author(author_text)
    if is_string(author_text) then

        self._author = author_text
    end
end

--- Enable localisation for this mod's description. Accepts either finalized text, or a localisation key.
---@param desc_text string The text supplied for the description. You can supply the text - ie., "My Mod's Description", or a loc-key, ie. "ui_text_replacements_my_dope_mod_description". Please note you can also skip this method, and just make a loc key called: `mct_[mct_mod_key]_description`, and MCT will automatically read that.
function mct_mod:set_description(desc_text)
    if is_string(desc_text) then
        self._description = desc_text
    end
end

--- Create a tooltip that will be displayed when hovering over the Mod row header in the left panel. Leave this blank to avoid any toolitp.
---@param text string
function mct_mod:set_tooltip_text(text)
    if is_string(text) then
        self._tooltip_text = text
    end
end

function mct_mod:get_tooltip_text()
    return GLib.HandleLocalisedText(self._tooltip_text, "", "mct_"..self:get_key().."_tooltip_text")
end



--- Set the ID for this mod.
---@param id string The ID for this mod. This is the ID that will be used to identify this mod in the workshop. Please note that this is NOT the workshop link, but the ID that is used to identify the mod in the workshop. For example, if the workshop link is: https://steamcommunity.com/sharedfiles/filedetails/?id=123456789, then the ID is 123456789.
function mct_mod:set_workshop_id(id)
    if is_string(id) then
        self._workshop_id = id
    end
end

function mct_mod:get_workshop_link()
    if self._workshop_id == "" then return "" end

    return "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. self._workshop_id
end

--- Ask for just the ?id= part of the workshop link. MCT will automatically add the rest of the link.
function mct_mod:set_workshop_link(link_text)
    -- if is_string(link_text) then
    --     -- check if they provided the entire link, or just the id
    --     if string.find(link_text, "steamcommunity.com/sharedfiles/filedetails/?id=") then
    --         -- they provided the entire link, so we'll keep it as it is.
    --     else
    --         -- check if the link is just a number; if so, we'll add the rest of the link
    --         if string.find(link_text, "%d+") then
    --             link_text = "https://steamcommunity.com/sharedfiles/filedetails/?id="..link_text
    --         else
    --             -- they're being tricksy and trying to submit a non-workshop link; we'll just ignore it.
    --             link_text = ""
    --         end
    --     end

    --     self._workshop_link = link_text
    -- end
end

-- Set the Github ID for this mod.
---@param id string The username/repo path for this mod's GitHub page. For example, if the GitHub link is: https://github.com/chadvandy/van_mct/ then the ID is chadvandy/van_mct.
function mct_mod:set_github_id(id)
    if is_string(id) then
        self._github_id = id
    end
end

function mct_mod:get_github_link()
    if self._github_id == "" then return "" end

    return "https://github.com/" .. self._github_id
end

--- Grabs the title text. First checks for a loc-key `mct_[mct_mod_key]_title`, then checks to see if anything was set using @{mct_mod:set_title}. If not, "No title assigned" is returned.
--- @return string title_text The returned string for this mct_mod's title.
function mct_mod:get_title()
    return GLib.HandleLocalisedText(self._title, "No title set", "mct_"..self:get_key().."_title")
end

--- Grabs the author text. First checks for a loc-key `mct_[mct_mod_key]_author`, then checks to see if anything was set using @{mct_mod:set_author}. If not, "No author assigned" is returned.
--- @return string author_text The returned string for this mct_mod's author.
function mct_mod:get_author()
    return GLib.HandleLocalisedText(self._author, "No author assigned", "mct_"..self:get_key().."_author")
end

--- Grabs the description text. First checks for a loc-key `mct_[mct_mod_key]_description`, then checks to see if anything was set using @{mct_mod:set_description}. If not, "No description assigned" is returned.
--- @return string description_text The returned string for this mct_mod's description.
function mct_mod:get_description()
    return GLib.HandleLocalisedText(self._description, "", "mct_"..self:get_key().."_description")
end

--- Returns all three localised texts - title, author, description.
--- @return string title_text The returned string for this mct_mod's title.
--- @return string author_text The returned string for this mct_mod's author.
--- @return string description_text The returned string for this mct_mod's description.
function mct_mod:get_localised_texts()
    return 
        self:get_title(),
        self:get_author(),
        self:get_description()
end

--- Returns every @{mct_option} attached to this mct_mod.
function mct_mod:get_options()
    return self._options
end

--- Returns every @{mct_option} of a type.
---@param option_type string The option_type to limit the search by.
function mct_mod:get_option_keys_by_type(option_type)
    if not is_string(option_type) then
        err("Trying `get_option_keys_by_type` for mod ["..self:get_key().."], but type provided is not a string! Returning false.")
        return false
    end

    if not mct:is_valid_option_type(option_type) then
        err("Trying `get_option_keys_by_type` for mod ["..self:get_key().."], but type ["..option_type.."] is not a valid type! Returning false.")
        return false
    end

    return self._options_by_type[option_type]
end

--- Returns a @{mct_option} with the specific key on the mct_mod.
---@param option_key string The unique identifier for the desired mct_option.
---@param is_test boolean? Whether we're testing for an existing option with this key, to ignore the error when none are found.
---@return MCT.Option?
function mct_mod:get_option_by_key(option_key, is_test)
    if not is_string(option_key) then
        err("Trying `get_option_by_key` for mod ["..self:get_key().."] but key provided ["..tostring(option_key).."] is not a string! Returning nil.")
        return nil
    end
    
    if not self._options[option_key] then
        if not is_test == true then
            GLib.Warn("Trying `%s:get_option_by_key(%s)`, but no option exists with that key!", self:get_key(), option_key)
            return nil
        end
    end

    return self._options[option_key]
end

--- Creates a new @{mct_option} with the specified key, of the desired type.
--- Use this! It calls an internal function, @{mct_option.new}, but wraps it with error checking and the like.
---@overload fun(self:MCT.Mod, self:MCT.Mod, option_key:string, option_type:"checkbox"):MCT.Option.Checkbox
---@overload fun(self:MCT.Mod, option_key:string, option_type:"dropdown"):MCT.Option.Dropdown
---@overload fun(self:MCT.Mod, option_key:string, option_type:"dropdown_game_object"):MCT.Option.SpecialDropdown
---@overload fun(self:MCT.Mod, option_key:string, option_type:"slider"):MCT.Option.Slider
---@overload fun(self:MCT.Mod, option_key:string, option_type:"text_input"):MCT.Option.TextInput
---@overload fun(self:MCT.Mod, option_key:string, option_type:"dummy"):MCT.Option.Dummy
---@param option_key string The unique identifier for the new mct_option.
---@param option_type MCT.OptionType The type for the new mct_option.
---@return MCT.Option?
function mct_mod:add_new_option(option_key, option_type)
    logf("Creating a new option %s to mod %s", option_key, self:get_key())
    -- check first to see if an option with this key already exists; if it does, return that one!
    local test = self:get_option_by_key(option_key, true)
    if mct:is_mct_option(test) then
        log("Trying `add_new_option` for mod ["..self:get_key().."], but there's already an option with the key ["..option_key.."]. Returning that option!")
        return test
    end

    log("Adding option with key ["..option_key.."] to mod ["..self:get_key().."].")
    if not is_string(option_key) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return
    end

    if option_key:starts_with("__") then
        return errf("Trying `add_new_option()` for mod [%s], but option key [%s] isn't valid because it starts with __. Please don't start your option key with that - it's reserved for MCT stuff.", self:get_key(), option_key)
    end

    if not is_string(option_type) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a string! Returning false.")
        return
    end

    if not mct:is_valid_option_type(option_type) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a valid type! Returning false.")
        return
    end

    local option_class = mct:get_option_type(option_type)
    ---@cast option_class MCT.Option
    local new_option = option_class:new(self, option_key)

    self._options[option_key] = new_option
    self._options_by_type[option_type][#self._options_by_type[option_type]+1] = option_key
    self._options_by_index_order[#self._options_by_index_order+1] = option_key


    --if mct._initalized then
        --log("Triggering MctNewOptionCreated")
        core:trigger_custom_event("MctNewOptionCreated", {["mct"] = mct, ["mod"] = self, ["option"] = new_option})
    --end


    return new_option
end

-- Add a new main page tab to this mod.
--- This is the main page tab that appears in the main page of the UI.
---@param title string The title for this tab.
---@param tooltip string The tooltip for this tab.
---@param populate_function fun(UIComponent) The description of this tab, as it appears in the UI.
function mct_mod:add_main_page_tab(title, tooltip, populate_function)
    if not is_string(title) then
        err("Trying `add_main_page_tab()` for mod ["..self:get_key().."] but title provided ["..tostring(title).."] is not a string! Returning false.")
        return
    end

    if not is_string(tooltip) then
        err("Trying `add_main_page_tab()` for mod ["..self:get_key().."] but tooltip provided ["..tostring(tooltip).."] is not a string! Returning false.")
        return
    end

    if not is_function(populate_function) then
        err("Trying `add_main_page_tab()` for mod ["..self:get_key().."] but populate_function provided ["..tostring(populate_function).."] is not a function! Returning false.")
        return
    end

    local tab = {
        title = title,
        tooltip = tooltip,
        populate_function = populate_function,
    }

    self._main_page_tabs[#self._main_page_tabs+1] = tab
end

--- Get all main page tabs for this mod.
---@return table<number, {title:string, tooltip:string, populate_function:fun(UIComponent)}>
function mct_mod:get_main_page_tabs()
    return self._main_page_tabs
end

--- This function removes an @{mct_option} from this mct_mod. Be very sure you want to call this - it can have potential unwanted repercussions.
--- This means the mct_option is gone entirely - it won't be in the UI, it won't be tracked in settings (but it will be cached), it won't be obtainable using `get_option_by_key()`.
---@param option_key string The option that's being disgustingly destroyed, how dare you?
function mct_mod:delete_option(option_key)
    if not is_string(option_key) then
        err("delete_option() called on mct_mod ["..self:get_key().."], but the option_key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return false
    end

    local option = self:get_option_by_key(option_key)
    if not mct:is_mct_option(option) then
        err("delete_option() called on mct_mod ["..self:get_key().."], but there's no mct_option with the key ["..option_key.."] found!")
        return false
    end

    -- remove it from this mct_mod!
    -- this doesn't remove the mct_option from memory entirely - just from the mct_mod's list of options - but Lua will kill it eventually.
    self._options[option_key] = nil
end

--- bloop
--- @local
--- @function mct_mod:clear_uics
function mct_mod:clear_uics(b)
    if not is_boolean(b) then b = true end

    local opts = self:get_options()
    for _, option in pairs(opts) do
        option:clear_uics(b)
    end

    local sections = self:get_sections()
    for _, section in pairs(sections) do
        section:clear_uics()
    end

    self._row_uic = nil
    self.__uics = {}
end

function mct_mod:toggle_subrows(b)
    --- toggle __bRowsOpen and change the visibility of all the subrows (but not the main row)
    if not is_boolean(b) then b = not self.__bRowsOpen end
    self.__bRowsOpen = b

    if is_boolean(b) then
        -- we have to manually set the button since it wasn't directly pressed!
        local button_open_close = self.__uics.button_open_close

        if b then
            button_open_close:SetState("selected")
        else
            button_open_close:SetState("active")
        end
    end

    local pages = self:get_settings_pages()
    for _, page in ipairs(pages) do
        -- skip the main page
        if self:get_main_page():get_key() ~= page:get_key() then
            local row = page:get_row_uic()
            row:SetVisible(self.__bRowsOpen)
        end
    end
end

---@param parent UIComponent
function mct_mod:create_row(parent)
    local row = core:get_or_create_component(self:get_key(), "ui/groovy/buttons/button_row", parent)
    row:SetVisible(true)
    row:SetCanResizeHeight(true) row:SetCanResizeWidth(true)
    row:Resize(parent:Width() * 0.95, 34 * 1.8)
    row:SetDockingPoint(2)
    
    row:SetState("active")
    row:SetProperty("mct_mod", self:get_key())
    row:SetProperty("mct_layout", self:get_main_page():get_key())

    local txt_uic = find_uicomponent(row, "dy_title")

    txt_uic:Resize(row:Width() - 40, row:Height() * 0.9)
    txt_uic:SetTextXOffset(5, 5)
    txt_uic:SetTextYOffset(0, 0)

    local title_txt = self:get_title()
    local author_txt = self:get_author()

    if not is_string(title_txt) then
        title_txt = "No title assigned"
    end

    title_txt = title_txt .. "\n" .. author_txt

    txt_uic:SetStateText(title_txt)

    local tt = self:get_tooltip_text()

    if is_string(tt) and tt ~= "" then
        row:SetTooltipText(tt, true)
    end

    local button_open_close = core:get_or_create_component("button_open_close", "ui/templates/square_small_toggle_plus_minus", row)
    button_open_close:SetProperty("mct_mod", self:get_key())

    local button_more_options = core:get_or_create_component("button_more_options", "ui/mct/more_options_button", row)
    button_more_options:SetProperty("mct_mod", self:get_key())

    button_open_close:SetDockingPoint(4)
    button_open_close:SetDockOffset(5, 0)
    button_open_close:SetTooltipText("Open/Close", true)
    -- button_open_close:SetState("selected")

    button_more_options:SetContextObject(cco("CcoScriptObject", "mct_mod_commands"))
    button_more_options:SetDockingPoint(6)
    button_more_options:SetDockOffset(-8, 0)
    button_more_options:SetTooltipText("More Options", true)

    if self:is_disabled() then
        row:SetState("inactive")
        row:SetInteractive(true)
        row:SetTooltipText("[[col:red]]Disabled||" .. self:get_disabled_reason() .. "[[/col]]", true)
        
        button_open_close:SetVisible(false)
        button_more_options:SetState("inactive")
        txt_uic:SetStateText("[[col:red]]"..title_txt .. "[[/col]]")
    else
        --- create the subpages for this mod row and then hide them to be reopened when this mod is selected.
        for i, settings_page in ipairs(self:get_settings_pages()) do
            settings_page:create_row_uic()
        end
    end

    self.__uics = {
        row = row,
        button_open_close = button_open_close,
        button_more_options = button_more_options,
        txt_uic = txt_uic
    }

    self:get_main_page():set_row_uic(row)
    self:set_row_uic(row)
end

--- INTERNAL ONLY.
--- Set the row-header UIC for this mod object, for easy retrieval later.
---@param uic UIC
function mct_mod:set_row_uic(uic)
    if not is_uicomponent(uic) then return end
    
    self._row_uic = uic
end

---@return UIC #The row header UIC for this mod.
function mct_mod:get_row_uic()
    return self._row_uic
end

return mct_mod
