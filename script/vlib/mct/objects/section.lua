---- Section Object
--- @class MCT.Section

local mct = get_mct()
-- local vlib = get_vandy_lib()
local log,logf,err,errf = get_vlog("[mct]")

local sorting = {
    ---@param obj MCT.Section
    key = function(obj)     
        local ret = {}
        local options = obj:get_options()
    
        for option_key, _ in pairs(options) do
            table.insert(ret, option_key)
        end
    
        table.sort(ret)
    
        return ret 
    end,
    ---@param obj MCT.Section
    index = function(obj)
        local ret = {}

        local valid_options = obj:get_options()
    
        -- table that has all mct_mod options listed in the order they were created via mct_mod:add_new_option
        -- array of option_keys!
        local order_by_option_added = obj:get_mod()._options_by_index_order
    
        -- loop through this table, check to see if the option iterated is in this section, and if it is, add it to the ret table, next in line
        for i = 1, #order_by_option_added do
            local test = order_by_option_added[i]
    
            if valid_options[test] ~= nil then
                -- set this option key as the next in the ret table
                ret[#ret+1] = test
            end
        end
    
        return ret
    end,
    ---@param obj MCT.Section
    localised_text = function(obj)
        -- return table, which will be the sorted option keys from top-left to bottom-right
        local ret = {}

        -- texts is the sorted list of option texts
        local texts = {}

        -- table linking localised text to a table of option keys. If multiple options have the same localised text, it will be `["Localised Text"] = {"option_key_a", "option_key_b"}`
        -- else, it's just `["Localised Text"] = {"option_key"}`
        local text_to_option_key = {}

        -- all options
        local options = obj:get_options()

        for option_key, option_obj in pairs(options) do
            -- grab this option's localised text
            local localised_text = option_obj:get_localised_text()
            
            -- toss it into the texts table, and link it to the option key
            texts[#texts+1] = localised_text

            -- check if this localised text was already linked to something
            local test = text_to_option_key[localised_text]

            if is_nil(text_to_option_key[localised_text]) then
                -- if not, set it equal to the key
                text_to_option_key[localised_text] = {option_key}
            else
                if is_table(test) then
                    -- this is ugly, I'm sorry.
                    text_to_option_key[localised_text][#text_to_option_key[localised_text]+1] = option_key
                end
            end
        end

        -- sort the texts alphanumerically.
        table.sort(texts)

        -- loop through texts, grab the relevant option key, and then add that option key to ret
        -- if multiple option keys are linked to this text, add them in order added, whatever
        for i = 1, #texts do
            -- grab the localised text at this index
            local text = texts[i]

            -- grab attached options
            local attached_options = text_to_option_key[text]

            -- loop through attached option keys (will only be 1 usually) and then add them to the ret table
            for j = 1, #attached_options do
                local option_key = attached_options[j]
                ret[#ret+1] = option_key
            end
        end

        return ret
    end
}


---@class MCT.Section
local mct_section_defaults = {
    ---@type string Identifying key for this section.
    _key = "",

    ---@type string Display text for this section.
    _text = "No text assigned",

    ---@type string Hovered-on text for this section.
    ---@see mct_section#set_tooltip_text
    _tooltip_text = "",

    ---@type UIC UI Object for the header row itself.
    _header = nil,

    ---@type UIC[]
    _dummy_rows = {},

    ---@type table<string, MCT.Option> Options linked to this section.
    _options = {},

    _ordered_options = {},

    ---@type boolean Visibility.
    _visible = true,

    ---@type MCT.Mod
    _mod = nil,

    ---@type function
    _visibility_change_callback = nil,

    _sort_order_function = sorting.key,
}

---@class MCT.Section : Class
---@field __new fun():MCT.Section
local mct_section = new_class("MCT.Section", mct_section_defaults)

--- For internal use only. Use @{mct_mod:add_new_section}.
---@param key string The key to identify the new mct_section.
---@param mod MCT.Mod The mct_mod this section is a member of.
function mct_section.new(key, mod)
    local o = mct_section:__new()
    o._key = key
    o._mod = mod

    return o
end

--- Get the ordered keys of all options in this section, based on the sort-order-function determined by @{mct_section:set_option_sort_function}.
-- @treturn {string,...} ordered_options An array of the ordered option keys, [1] is the first key, [2] is the second, so on.
-- @treturn number num_total The total number of options in this section, for UI creation.
function mct_section:get_ordered_options()
    local ordered_options = self._ordered_options
    local num_total = 0

    for _,_ in pairs(ordered_options) do
        num_total = num_total + 1
    end
    
    return ordered_options, num_total
end

--- Set an option key at a specific index, for the @{mct_section:get_ordered_options} function.
-- Don't call this directly - use @{mct_section:set_option_sort_function}
---@param option_key string The option key being placed at the index.
---@param x number The x-value for the option. Somewhere between 1(left) and 3(right)
---@param y number The y-value for the option. 1 is the top row, etc.
function mct_section:set_option_at_index(option_key, x, y)
    if not is_string(option_key) then
        err("set_option_at_index() called for section ["..self:get_key().."] in mct mod ["..self:get_mod():get_key().."], but the option_key provided was not a string! Returning false.")
        return false
    end

    if not is_number(x) then
        err("set_option_at_index() called for section ["..self:get_key().."] in mct mod ["..self:get_mod():get_key().."], but the x arg provided was not a number! Returning false.")
        return false
    end

    if not is_number(y) then
        err("set_option_at_index() called for section ["..self:get_key().."] in mct mod ["..self:get_mod():get_key().."], but the y arg provided was not a number! Returning false.")
        return false
    end

    local index = tostring(x)..","..tostring(y)

    --mct:log("Setting option key ["..option_key.."] to pos ["..index.."] in section ["..self:get_key().."]")

    self._ordered_options[index] = option_key
end

--- Call the internal ._sort_order_function, determined by @{mct_section:set_option_sort_function}
-- @local
function mct_section:sort_options()
    local retval = {}

    -- grab the return value from the internal sort order function
    local ordered_options = self:_sort_order_function()
    local mct_mod = self:get_mod()

    -- loop through ordered options, and get rid of any options that are set as invisible for UI sake
    for i = 1, #ordered_options do
        local option_key = ordered_options[i]
        local option_obj = mct_mod:get_option_by_key(option_key)

        if not mct:is_mct_option(option_obj) then 
            --- TODO warn
            log("sort_options() called but the option found ["..option_key.."] is not a valid MCT option! Skipping.")
        else

            -- if it's set as visible, pass it forward
            -- if it's invisible but still set to exist in the UI, pass it forward
            -- if it's invisible and not, remove it
            if option_obj:get_uic_visibility() == true or (option_obj:get_uic_visibility() == false and option_obj._uic_in_ui == true) then
                retval[#retval+1] = option_key
            end
        end
    end

    -- return the filtered options
    return retval
end

--- Set the option-sort-function for this section's options.
-- You can pass "key_sort" for @{mct_section:sort_options_by_key}
-- You can pass "index_sort" for @{mct_section:sort_options_by_index}
-- You can pass "text_sort" for @{mct_section:sort_options_by_localised_text}
-- You can also pass a full function, for example:
-- mct_section:set_option_sort_function(
--      function()
--          local ordered_options = {}
--          local options = mct_section:get_options()
--          for option_key, option_obj in pairs(options) do
--              ordered_options[#ordered_options+1] = option_key
--          end
-- 
--          -- alphabetically sort the options
--          table.sort(ordered_options)
-- 
--          -- reverse the order
--          table.sort(ordered_options, function(a,b) return a > b end)
--      end
-- )
---@param sort_func function|string The sort function provided. Either use one of the two strings above, or a custom function like the above example.
function mct_section:set_option_sort_function(sort_func)
    if is_string(sort_func) then
        if sort_func == "key_sort" then
            self._sort_order_function = sorting.key
        elseif sort_func == "index_sort" then
            self._sort_order_function = sorting.index
        elseif sort_func == "text_sort" then
            self._sort_order_function = sorting.localised_text
        else
            err("set_option_sort_function() called for section ["..self:get_key().."], but the sort_func provided ["..sort_func.."] is an invalid string!")
            return false
        end
    elseif is_function(sort_func) then
        self._sort_order_function = sort_func
    else
        err("set_option_sort_function() called for section ["..self:get_key().."], but the sort_func provided isn't a string or a function!")
        return false
    end
end

--- Clears the UICs saved in this section to prevent wild crashes or whatever.
-- @local
function mct_section:clear_uics()
    self._dummy_rows = {}
    self._header = nil
end

--- Saves the dummy rows (every 3 options in the UI is a dummy_row) in the mct_section.
-- @local
function mct_section:add_dummy_row(uic)
    if not is_uicomponent(uic) then
        err("add_dummy_row() called for section ["..self:get_key().."], but the uic provided isn't a UIComponent!")
        return false
    end

    self._dummy_rows[#self._dummy_rows+1] = uic
end

--- The UI trigger for the section opening or closing.
-- Internal use only. Use @{mct_section:set_visibility} if you want to manually change the visibility elsewhere.
---@param event_free boolean? Whether to trigger the "MctSectionVisibilityChanged" event. True is sent when the section is first created.
function mct_section:uic_visibility_change(event_free)
    local visibility = self._visible

    local attached_rows = self._dummy_rows
    for i = 1, #attached_rows do
        if not is_uicomponent(attached_rows[i]) then
            -- skip
            attached_rows[i] = nil
        else
            local row = attached_rows[i]
            row:SetVisible(visibility)
        end
    end

    -- also change the state of the UI header
    if visibility then
        self._header:SetState("selected")
        -- set to selected
    else
        self._header:SetState("active")
        -- set to active
    end

    if not event_free then
        core:trigger_custom_event("MctSectionVisibilityChanged", {["mct"] = mct, ["mod"] = self:get_mod(), ["section"] = self, ["visibility"] = visibility})

        self:process_callback()
    end
end

--- Add a callback to be triggered after @{mct_section:uic_visibility_change} is called.
---@param callback function The callback to trigger when the visibility is changed.
function mct_section:add_section_visibility_change_callback(callback)
    if not is_function(callback) then
        err("add_section_visibility_change_callback() called for section ["..self:get_key().."] in mod ["..self:get_mod():get_key()..", but the callback passed is not a function!")
        return false
    end

    self._visibility_change_callback = callback
end

--- Trigger the callback from @{mct_section:add_section_visibility_change_callback}
-- @local
function mct_section:process_callback()
    local f = self._visibility_change_callback

    -- no callback set, skip
    if not is_function(f) then
        return false
    end

    f(self)
end

--- Get the dummy rows for the options in this section.
-- Not really needed outside.
-- @local
function mct_section:get_dummy_rows()
    return self._dummy_rows or {}
end

--- Get the key for this section.
-- @treturn string The key for this section.
function mct_section:get_key()
    return self._key
end

--- Get the @{mct_mod} that owns this section.
-- @treturn mct_mod The owning mct_mod for this section.
function mct_section:get_mod()
    return self._mod
end

--- Get the header text for this section.
-- Either mct_[mct_mod_key]_[section_key]_section_text, in a .loc file,
-- or the text provided using @{mct_section:set_localised_text}
-- @treturn string The localised text for this section, used as the title.
function mct_section:get_localised_text()
    -- default to checking the loc files
    local text = common.get_localised_string("mct_"..self:get_mod():get_key().."_"..self:get_key().."_section_text")

    if text ~= "" then
        return text
    else
        -- nothing found, check for anything supplied by `set_localised_text()`, or send the default "No text assigned"
        text = vlib_format_text(self._text)
    end

    if not is_string(text) or text == "" then
        text = "No text assigned"
    end


    return text
end

--- Grab whether this mct_section is set to be visible or not - whether it's "opened" or "closed"
-- Works to read the UI, as well.
-- @treturn boolean Whether the mct_section is currently visible, or whether the mct_section will be visible when it's next created.
function mct_section:is_visible()
    return self._visible
end

--- Set the visibility for the mct_section.
-- This works while the UI currently exists, or to set its visibility next time the panel is opened.
-- Triggers @{mct_section:uic_visibility_change} automatically.
---@param is_visible boolean True for open, false for closed.
function mct_section:set_visibility(is_visible)
    if is_nil(is_visible) then enable = true end

    if not is_boolean(is_visible) then
        err("set_visibility() called for section ["..self:get_key().."], but the is_visible argument passed isn't a boolean or nil! Returning false.")
        return false
    end

    self._visible = is_visible

    -- test if the UI object exists - if it does, call the UI wrapper!
    if is_uicomponent(self._header) then
        self:uic_visibility_change()
    end
end

--- Set the title for this section.
-- Works the same as always - you can pass hard text, ie. mct_section:set_localised_text("My Section")
-- or a localised key, ie. mct_section:set_localised_text("my_section_loc_key", true)
---@param text string The localised text for this mct_section title. Either hard text, or a loc key.
---@param is_localised boolean If setting a loc key as the localised text, set this to true.
function mct_section:set_localised_text(text, is_localised)
    if not is_string(text) then
        err("set_localised_text() called for section ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")
        return false
    end

    if is_localised then text = "{{loc:" .. text .. "}}" end

    -- if not is_boolean(is_localised) then
    --     err("set_localised_text() called for section ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the is_localised arg supplied is not a boolean or nil! Returning false.")
    --     return false
    -- end

    self._text = text
end

--- Set tooltip text for this section, which'll appear when hovered over.
---@param text string The text to display. Use `||` at any point to perform the cool tooltip linebreaks that can happen, where it expands after hovering over. You can also use any existing CA loc formating, including [[col:]][[/col]] and other stuff. I've also added a {{loc:loc_key}} functionality, so you can include localised text.
function mct_section:set_tooltip_text(text)
    assert(is_string(text), "set_tooltip_text() called for section ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")

    self._tooltip_text = text
end

function mct_section:get_tooltip_text()
    -- default to checking the loc files
    local text = common.get_localised_string("mct_"..self:get_mod():get_key().."_"..self:get_key().."_section_tooltip_text")

    if text ~= "" then
        return text
    else
        -- nothing found, check for anything supplied by `set_localised_text()`, or send the default "No text assigned"
        text = vlib_format_text(self._tooltip_text)
    end

    if not is_string(text) then
        text = ""
    end

    return text
end

--- Assign an option to this section.
-- Automatically called through @{mct_option:set_assigned_section}.
---@param option_obj MCT.Option The option object to assign into this section.
function mct_section:assign_option(option_obj)
    
    local current_mod = self:get_mod()
    
    if is_string(option_obj) then
        -- try to get an option obj with this key
        option_obj = current_mod:get_option_by_key(option_obj)
    end

    if not mct:is_mct_option(option_obj) then
        err("assign_option() called for section ["..self:get_key().."], but the option_obj provided ["..tostring(option_obj).."] is not an mct_option!  Cancelling")
        return false
    end
    
    local option_key = option_obj:get_key()
    
    -- remove this option from any previous section it was assigned to
    local old_assignment = option_obj:get_assigned_section()
    if old_assignment then
        local old_section = current_mod:get_section_by_key(old_assignment)
        if old_section then
            old_section._options[option_key] = nil
        end
    end

    self._options[option_key] = option_obj

    option_obj._assigned_section = self:get_key() -- we can't call option_obj:set_assigned_section here without creating an infinite loop
end

--- Return all the options assigned to the mct_section.
-- @treturn {[string]=mct_object,...} The table of all the options in this mct_section.
function mct_section:get_options()
    return self._options
end

return mct_section
