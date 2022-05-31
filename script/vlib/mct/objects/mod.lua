--- The mct_mod object.
--- This holds all of the details for one mod - name, author, available options, UI appearances, etc.
--- @class MCT.Mod

-- TODO make "Finalize settings" validate all MCT options; if some are invalid, give some UX notifs that they're not valid. esp. for the textboxes.
--- TODO move all local functions to *actual* locals? Or something similar?
--- TODO emmylua

local mct = get_mct()

local log,logf,err,errf = get_vlog("[mct]")

local sort_functions = {
    --- One of the default sort-section function.
    -- Sort the sections by their section key - from "!my_section" to "zzz_my_section"
    key = function(self)
        local ret = {}
        local sections = self:get_sections()

        for section_key, _ in pairs(sections) do
            table.insert(ret, section_key)
        end

        table.sort(ret)

        return ret
    end,

    --- One of the default sort-section functions.
    -- Sort the sections by the order in which they were added in the `mct/settings/?.lua` file.
    index = function(self)
        local ret = {}

        -- table that has all mct_mod sections listed in the order they were created via mct_mod:add_new_section
        -- array of section_keys!
        local order_by_section_added = self._sections_by_index_order
    
        -- copy the table
        for i = 1, #order_by_section_added do
            ret[#ret+1] = order_by_section_added[i]
        end
    
        return ret
    end,

    ---- One of the default sort-option functions.
    --- Sort the section by their localised text - from "Awesome Options" to "Zoidberg Goes Woop Woop Woop"
    localised_text = function(self)
        -- return table, which will be the sorted sections from top to bottom
        local ret = {}

        -- texts is the sorted list of section texts
        local texts = {}

        -- table linking localised text to a table of section keys. If multiple section have the same localised text, it will be `["Localised Text"] = {"section_key_a", "section_key_b"}`
        -- else, it's just `["Localised Text"] = {"section_key"}`
        local text_to_section_key = {}

        -- all sections
        local sections = self:get_sections()

        for section_key, section_obj in pairs(sections) do
            -- grab this section's localised text
            local localised_text = section_obj:get_localised_text()
            
            -- toss it into the texts table, and link it to the section key
            texts[#texts+1] = localised_text

            -- check if this localised text was already linked to something
            local test = text_to_section_key[localised_text]

            if is_nil(text_to_section_key[localised_text]) then
                -- if not, set it equal to the key
                text_to_section_key[localised_text] = {section_key}
            else
                if is_table(test) then
                    -- this is ugly, I'm sorry.
                    text_to_section_key[localised_text][#text_to_section_key[localised_text]+1] = section_key
                end
            end
        end

        -- sort the texts alphanumerically.
        table.sort(texts)

        -- loop through texts, grab the relevant section key, and then add that section key to ret
        -- if multiple section keys are linked to this text, add them in order added, whatever
        for i = 1, #texts do
            -- grab the localised text at this index
            local text = texts[i]

            -- grab attached sections
            local attached_sections = text_to_section_key[text]

            -- loop through attached section keys (will only be 1 usually) and then add them to the ret table
            for j = 1, #attached_sections do
                local section_key = attached_sections[j]
                ret[#ret+1] = section_key
            end
        end

        return ret
    end
}

--- the table.
---@class MCT.Mod
local mct_mod_defaults = {
    ---@type string The key for this mod object.
    _key = "",

    ---@type table The patches created for this mod - the various patches and the relative dates and info. Highest index is the most recent, first index is the first one made.
    _patches = {},

    ---@type number The last patch num viewed by the current user. Saved by MCT.
    _last_viewed_patch = 0,

    -- TODO fill in.
    ---@type table<string, MCT.Option>
    _options = {},

    _options_by_type = mct:get_valid_option_types_table(),

    _options_by_index_order = {},

    _coords = {},

    _finalized_settings = {},

    _sections = {},
    _sections_by_index_order = {},
    _section_sort_order_function = sort_functions.key,

    --- Used to store the path to a log file, for the internal MCT logging functionality.
    _log_file_path = nil,

    _title = "No Title Assigned",
    _author = "No Author Assigned",
    _description = "No Description Assigned",

    ---@type string The tooltip text for this mod, shown on the row header.
    _tooltip_text = "",
    -- _workshop_url = "",
}

---@class MCT.Mod : Class
---@field __new fun():MCT.Mod
local mct_mod = VLib.NewClass("MCT_Mod", mct_mod_defaults)

--- For internal use, called by the MCT Manager. Creates a new mct_mod object.
---@param key string The key for the new mct_mod. Has to be unique!
---@return MCT.Mod
---@see mct:register_mod
function mct_mod:new(key)
    local o = mct_mod:__new()
    o._key = key

    --- TODO do I want this?
    -- start with the default section, if none are specified this is what's used
    o:add_new_section("default", "mct_mct_mod_default_section_text", true)

    return o
end

-- TODO move this back to settings?
--- INTERNAL USE ONLY.
-- This constructs the string used in mct_settings.lua, for this mod.
-- Done as a method of mct_mod so we can read mct_mod/mct_option where necessary.
-- For instance, used to enact precision on slider floats.
-- @treturn string The mct_settings.lua string for this mod, ie. `["mod_key"] = {["option_key"] = "setting", ...}`
function mct_mod:save_mct_settings()
    local retstr = ""

    -- start with the key and start line
    retstr = "\t[\""..self:get_key().."\"] = {\n"

    -- loop through all options
    local all_options = self:get_options()

    -- Save the last patch viewed!
    do
        local last_view = self:get_last_viewed_patch()
        if last_view then
            retstr = retstr .. "\t\t[\"__patch\"] = " .. last_view .. ",\n"
        end
    end

    for option_key, option_obj in pairs(all_options) do
        if option_obj:get_type() == "dummy" then
            -- skip dummy's
        else
            retstr = retstr .. "\t\t[\""..option_key.."\"] = {\n"

            retstr = retstr .. "\t\t\t[\"_setting\"] = "

            local v = option_obj:get_finalized_setting()

            if is_string(v) then
                retstr = retstr .. "\"" .. v .. "\"" .. ",\n"
            elseif is_number(v) then
                if option_obj:get_type() == "slider" then
                    local precision = option_obj:get_values().precision or 0

                    v = string.format("%."..precision.."f", v)
                    
                    retstr = retstr .. v .. ",\n"
                else
                    -- issue? what?
                    retstr = retstr .. tostring(v) .. ",\n"
                end            
            elseif is_boolean(v) then
                retstr = retstr .. tostring(v) .. ",\n"
            end
            
            retstr = retstr .. "\t\t},\n"
        end
    end

    retstr = retstr .. "\t},\n"

    return retstr
end

--- Getter for any @{mct_section}s linked to this mct_mod.
---@param section_key string The identifier for the section searched for.
---@return MCT.Section
function mct_mod:get_section_by_key(section_key)
    if not is_string(section_key) then
        err("get_section_by_key() called on mct_mod ["..self:get_key().."], but the section_key supplied is not a string! Returning nil.")
        return nil
    end

    local t = self._sections[section_key]
    if not mct:is_mct_section(t) then
        err("get_section_by_key() called on mct_mod ["..self:get_key().."], but the section found in self._sections is not an mct_section! Returning nil.")
        return nil
    end

    return t
end

--- Add a new section to the mod's settings view, to separate them into several categories.
-- When this function is called, it assumes all following options being defined are being assigned to this section, unless further specified with
-- mct_option.
--- @param section_key string The unique identifier for this section.
--- @param localised_name string? The localised text for this section. You can provide a direct string - "My Section Name" - or a loc key - "`loc_key_example_my_sect ion_name`". If a loc key is provided, it will check first at runtime to see if that localised text exists. If no localised_name is provided, it will default to "No Text Assigned". Can leave this and the other blank, and use @{mct_section:set_localised_text} instead.
--- @param is_localised boolean? If a loc key is provided in localised_name, set this to true, please.
--- @return MCT.Section # Returns the mct_section object created from this call.
function mct_mod:add_new_section(section_key, localised_name, is_localised)
    if not is_string(section_key) then
        err("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the section_key supplied was not a string! Returning false.")
        return false
    end

    if not is_string(localised_name) then
        localised_name = ""
        --err("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the localised_name supplied was not a string! Returning false.")
        --return false
    end

    if is_nil(is_localised) then is_localised = false end

    if not is_boolean(is_localised) then
        err("add_new_section() tried on mct_mod with key ["..self:get_key().."], but the is_localised supplied was not nil or a boolean! Returning false.")
        return false
    end

    local new_section = mct._MCT_SECTION.new(section_key, self)

    if localised_name ~= "" then
        new_section:set_localised_text(localised_name, is_localised)
    end

    self._sections[section_key] = new_section
    self._sections_by_index_order[#self._sections_by_index_order+1] = section_key
    self._last_section = new_section

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
-- @treturn string
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

    --mct.ui:section_visibility_change(section_key, visible)
end

--- Internal use only, no real need for use anywhere else.
-- Specifically used when creating new options, to find the last-made section.
-- @local
function mct_mod:get_last_section()
    -- return the last created section
    return self._last_section
end

--- Getter for the mct_mod's key
---@return string key The key for this mct_mod
function mct_mod:get_key()
    return self._key
end

--- Call the internal ._section_sort_order_function, determined by @{mct_mod:set_section_sort_function}
-- @local
function mct_mod:sort_sections()
    -- perform the wrapped sort order function

    -- TODO protect it?
    -- protect it with a pcall to catch any issues with a custom sort order func
    return self:_section_sort_order_function()
end

--- Set the section-sort-function for this mod's sections.
--- You can pass "key_sort" for @{mct_mod:sort_sections_by_key}.
--- You can pass "index_sort" for @{mct_mod:sort_sections_by_index}.
--- You can pass "text_sort" for @{mct_mod:sort_sections_by_localised_text}.
--- You can also pass a full function, see usage below.
--- @usage    mct_mod:set_sections_sort_function(
---      function()
---          local ordered_sections = {}
---          local sections = mct_mod:get_sections()
---          for section_key, section_obj in pairs(sections) do
---              ordered_sections[#ordered_sections+1] = section_key
---          end
--- 
---          -- alphabetically sort the sections
---          table.sort(ordered_sections)
--- 
---          -- reverse the order
---          table.sort(ordered_sections, function(a,b) return a > b end)
---      end
---     )
---@param sort_func function|"key_sort"|"index_sort"|"text_sort" The sort function provided. Either use one of the two strings above, or a custom function like the below example.
function mct_mod:set_section_sort_function(sort_func)
    if is_string(sort_func) then
        if sort_func == "key_sort" then
            self._section_sort_order_function = sort_functions.key
        elseif sort_func == "index_sort" then
            self._section_sort_order_function = sort_functions.index
        elseif sort_func == "text_sort" then
            self._section_sort_order_function = sort_functions.localised_text
        else
            err("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided ["..sort_func.."] is an invalid string!")
            return false
        end
    elseif is_function(sort_func) then
        self._section_sort_order_function = sort_func
    else
        err("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided isn't a string or a function!")
        return false
    end
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
    --self:set_positions_for_options()
end

--- Loops through all sections, and checks all options within each section, to save the x/y coordinates of each option.
--- Order the options by key within each section, giving sliders a full row to their own self
--- @local
function mct_mod:set_positions_for_options()
    local sections = self:get_sections()

    -- log("setting positions for options in mod ["..self:get_key().."]")
    
    for section_key, section_obj in pairs(sections) do
        -- log("in section ["..section_key.."].")

        local ordered_option_keys = section_obj:sort_options()

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

            if mct:is_mct_option(option_obj) then        
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

-- TODO change this to use changed_settings? 
--- Set all options to their default value in the UI
function mct_mod:revert_to_defaults()
    --log("Reverting to defaults for mod ["..self:get_key().."]")
    local all_options = self:get_options()

    for option_key, option_obj in pairs(all_options) do
        local current_val = option_obj:get_selected_setting()
        local default_val = option_obj:get_default_value()

        if current_val ~= default_val then
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

--- TODO implement this
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

--- TODO switch to Settings object
--- Used when finalizing the settings in MCT.
--- @local
function mct_mod:finalize_settings()
    -- local changed_options = mct.settings:get_changed_settings(self:get_key())
    -- if not is_table(changed_options) then
    --     -- this mod hasn't had any changed settings - skip!
    --     log("Finalizing settings for mod ["..self:get_key().."], but nothing was changed in this mod! Cool!")
    --     return false
    -- end

    -- log("Finalizing settings for mod ["..self:get_key().."]")

    -- for option_key, option_data in pairs(changed_options) do
    --     local option_obj = self:get_option_by_key(option_key)

    --     if not mct:is_mct_option(option_obj) then
    --         log("Trying to finalize settings for mct_mod ["..self:get_key().."], but there's no option with the key ["..option_key.."].")
    --         --return false
    --     else
    --         local new_setting = option_data.new_value
    --         local old_setting = option_data.old_value
    
    --         log("Finalizing setting for option ["..option_key.."], changing ["..tostring(old_setting).."] to ["..tostring(new_setting).."].")
    
    --         option_obj:set_finalized_setting(new_setting)
    --     end
    -- end

    -- --- TODO wrap this
    -- mct.settings.__changed_settings[self:get_key()] = nil
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

--- Returns the `finalized_settings` field of this `mct_mod`.
function mct_mod:get_settings()
    return mct.settings:get_settings_for_mod(self)
end


function mct_mod:get_settings_by_section(section_key)
    local retval = {}

    if not self:get_section_by_key(section_key) then
        VLib.Error("Trying to get settings within section %s of mod %s, but there is no section with that name!", section_key, self:get_key())
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
---@param is_localised boolean True if the title_text supplied is a loc key.
function mct_mod:set_title(title_text, is_localised)
    if is_string(title_text) then
        if is_localised then title_text = "{{loc:"..title_text.."}}" end

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
---@param is_localised boolean True if the desc_text supplied is a loc key.
function mct_mod:set_description(desc_text, is_localised)
    if is_string(desc_text) then
        if is_localised then desc_text = "{{loc:"..desc_text.."}}" end

        self._description = desc_text
    end
end

--- Create a tooltip that will be displayed when hovering over the Mod row header in the left panel. Leave this blank to avoid any toolitp.
---@param text string
---@param is_localised boolean?
function mct_mod:set_tooltip_text(text, is_localised)
    if is_string(text) then
        if is_localised then text = "{{loc:"..text.."}}" end

        self._tooltip_text = text
    end
end

function mct_mod:get_tooltip_text()
    local tooltip = common.get_localised_string("mct_"..self:get_key().."_tooltip_text")
    if tooltip ~= "" then
        return tooltip
    end

    tooltip = VLib.FormatText(self._tooltip_text)

    return tooltip or ""
end

--[[function mct_mod:set_workshop_link(link_text)
    if is_string(link_text) then
        self._workshop_link = link_text
    end
end]]

--- Grabs the title text. First checks for a loc-key `mct_[mct_mod_key]_title`, then checks to see if anything was set using @{mct_mod:set_title}. If not, "No title assigned" is returned.
--- @treturn string title_text The returned string for this mct_mod's title.
function mct_mod:get_title()
    -- check if a title exists in the localised texts!
    local title = common.get_localised_string("mct_"..self:get_key().."_title")
    if title ~= "" then
        return title
    end

    title = VLib.FormatText(self._title)
    -- if title.is_localised then
    --     local test = effect.get_localised_string(title.text)
    --     if test ~= "" then
    --         return test
    --     end
    -- end

    return title or "No title assigned"
end

--- Grabs the author text. First checks for a loc-key `mct_[mct_mod_key]_author`, then checks to see if anything was set using @{mct_mod:set_author}. If not, "No author assigned" is returned.
--- @treturn string author_text The returned string for this mct_mod's author.
function mct_mod:get_author()
    local author = common.get_localised_string("mct_"..self:get_key().."_author")
    if author ~= "" then
        return author
    end

    --if author == "" then
        --return
    --end

    return VLib.FormatText(self._author) --or "No author assigned"
end

--- Grabs the description text. First checks for a loc-key `mct_[mct_mod_key]_description`, then checks to see if anything was set using @{mct_mod:set_description}. If not, "No description assigned" is returned.
--- @treturn string description_text The returned string for this mct_mod's description.
function mct_mod:get_description()
    local description = common.get_localised_string("mct_"..self:get_key().."_description")
    if description ~= "" then
        return description
    end

    description = VLib.FormatText(self._description)
    -- if description.is_localised then
    --     local test = effect.get_localised_string(description.text)
    --     if test ~= "" then
    --         return test
    --     end
    -- end

    return description or "No description assigned"
end

--[[function mct_mod:get_workshop_link()
    return self._workshop_link
end]]

--- Returns all three localised texts - title, author, description.
--- @treturn string title_text The returned string for this mct_mod's title.
--- @treturn string author_text The returned string for this mct_mod's author.
--- @treturn string description_text The returned string for this mct_mod's description.
function mct_mod:get_localised_texts()
    return 
        self:get_title(),
        self:get_author(),
        self:get_description()
        --self:get_workshop_link()
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
---@return MCT.Option
function mct_mod:get_option_by_key(option_key)
    if not is_string(option_key) then
        err("Trying `get_option_by_key` for mod ["..self:get_key().."] but key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return false
    end

    if not self._options[option_key] then
        VLib.Warn("Trying `%s:get_option_by_key(%s)`, but no option exists with that key!", self:get_key(), option_key)
        return false
    end

    return self._options[option_key]
end

--- Creates a new @{mct_option} with the specified key, of the desired type.
--- Use this! It calls an internal function, @{mct_option.new}, but wraps it with error checking and the like.
---@overload fun(self:MCT.Mod, self:MCT.Mod, option_key:string, option_type:"checkbox"):MCT.Option.Checkbox
---@overload fun(self:MCT.Mod, option_key:string, option_type:"dropdown"):MCT.Option.Dropdown
---@overload fun(self:MCT.Mod, option_key:string, option_type:"slider"):MCT.Option.Slider
---@overload fun(self:MCT.Mod, option_key:string, option_type:"text_input"):MCT.Option.TextInput
---@overload fun(self:MCT.Mod, option_key:string, option_type:"dummy"):MCT.Option.Dummy
---@param option_key string The unique identifier for the new mct_option.
---@param option_type MCT.OptionType The type for the new mct_option.
---@return MCT.Option
function mct_mod:add_new_option(option_key, option_type)
    logf("Creating a new option %s to mod %s", option_key, self:get_key())
    -- check first to see if an option with this key already exists; if it does, return that one!
    local test = self:get_option_by_key(option_key)
    if mct:is_mct_option(test) then
        log("Trying `add_new_option` for mod ["..self:get_key().."], but there's already an option with the key ["..option_key.."]. Returning that option!")
        return test
    end

    log("Adding option with key ["..option_key.."] to mod ["..self:get_key().."].")
    if not is_string(option_key) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option key provided ["..tostring(option_key).."] is not a string! Returning false.")
        return false
    end

    if option_key:starts_with("__") then
        return errf("Trying `add_new_option()` for mod [%s], but option key [%s] isn't valid because it starts with __. Please don't start your option key with that - it's reserved for MCT stuff.", self:get_key(), option_key)
    end

    if not is_string(option_type) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a string! Returning false.")
        return false
    end

    if not mct:is_valid_option_type(option_type) then
        err("Trying `add_new_option()` for mod ["..self:get_key().."] but option type provided ["..tostring(option_type).."] is not a valid type! Returning false.")
        return false
    end

    logf("Here we goooo")

    local new_option
    local ok, err = pcall(function()

        logf("Creating option %s for mod %s", option_key, self:get_key())
    local option_class = mct:get_option_type(option_type)
    logf("Option class gotten for type %s", option_type)
    new_option = option_class:new(self, option_key)

    logf("Creating new option obj")

    logf("Saving %s._options['%s']", self:get_key(), option_key)

    self._options[option_key] = new_option
    self._options_by_type[option_type][#self._options_by_type[option_type]+1] = option_key
    self._options_by_index_order[#self._options_by_index_order+1] = option_key


    --if mct._initalized then
        --log("Triggering MctNewOptionCreated")
        core:trigger_custom_event("MctNewOptionCreated", {["mct"] = mct, ["mod"] = self, ["option"] = new_option})
    --end

    end) if not ok then errf(err) end

    return new_option
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
end


return mct_mod
