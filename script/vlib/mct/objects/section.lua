--- TODO change the two different section types - collapsible and not collapsible - to two different classes, the collapsible as a child of the other or whichever


---- Section Object
--- @class MCT.Section

local mct = get_mct()
-- local vlib = get_vandy_lib()
local log,logf,err,errf = get_vlog("[mct]")

local sorting = VLib.LoadModule("options", "script/vlib/mct/sort_functions/")


---@class MCT.Section
local mct_section_defaults = {
    ---@type string Identifying key for this section.
    _key = "",

    ---@type string Display text for this section.
    _text = "No text assigned",

    ---@type string An optional description for this section.
    ---@see
    _description = "",

    ---@type string Hovered-on text for this section.
    ---@see mct_section.set_tooltip_text
    _tooltip_text = "",

    ---@type UIC UI Object for the header row itself.
    _header = nil,

    ---@type table<string, MCT.Option> Options linked to this section.
    _options = {},

    _ordered_options = {},

    _true_ordered_options = {},

    ---@type boolean Whether this full section is collapsed (header visible, rows invisible)
    _is_collapsed = false,

    ---@type boolean Whether this full section is hidden in the UI.
    _is_hidden = false,

    ---@type MCT.Mod
    _mod = nil,

    ---@type MCT.Page.Settings TODO link sections to pages
    _page = nil,

    ---@type boolean Whether this section can be collapsed
    _is_collapsible = false,

    ---@type function
    _visibility_change_callback = nil,

    _sort_order_function = sorting.index,
}

---@class MCT.Section : Class
---@field __new fun():MCT.Section
local mct_section = VLib.NewClass("MCT.Section", mct_section_defaults)

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
-- @return {string,...} ordered_options An array of the ordered option keys, [1] is the first key, [2] is the second, so on.
-- @return number num_total The total number of options in this section, for UI creation.
function mct_section:get_ordered_options()
    local ordered_options = self._ordered_options
    local num_total = 0

    for _,_ in pairs(ordered_options) do
        num_total = num_total + 1
    end
    
    return ordered_options, num_total
end

---@param page MCT.Page.Settings
function mct_section:assign_to_page(page)
    if self._page then
        self._page:unassign_section(self)
    end

    self._page = page
    page:assign_section_to_page(self)
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

    self._true_ordered_options[#self._true_ordered_options+1] = option_key
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

        if not option_obj or not mct:is_mct_option(option_obj) then
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
    self._header = nil
    self._holder = nil
end

--- The UI trigger for the section opening or closing.
-- Internal use only. Use @{mct_section:set_visibility} if you want to manually change the visibility elsewhere.
---@param b boolean If this should be collapsed.
---@param event_free boolean? Whether to trigger the "MctSectionVisibilityChanged" event. True is sent when the section is first created.
function mct_section:set_collapsed(b, event_free)
    if is_nil(b) then b = true end
    if not is_boolean(b) then
        --- errmsg
        return false
    end

    self._is_collapsed = b

    self:ui_set_collapsed(event_free)
end

---@param event_free boolean? Whether to trigger the "MctSectionVisibilityChanged" event. True is sent when the section is first created.
function mct_section:ui_set_collapsed(event_free)
    local is_open = not self._is_collapsed
    local holder = self._holder

    if not is_uicomponent(holder) then return end
    
    local options = find_uicomponent(holder, "options_holder")
    if options then options:SetVisible(is_open) end

    local desc = find_uicomponent(holder, "description")
    if desc then desc:SetVisible(is_open) end

    -- also change the state of the UI header
    if is_open then
        self._header:SetState("selected")
    else
        self._header:SetState("active")
    end

    if not event_free then
        core:trigger_custom_event("MctSectionVisibilityChanged", {["mct"] = mct, ["mod"] = self:get_mod(), ["section"] = self, ["visibility"] = is_open})

        self:process_callback()
    end
end

--- Hide the Section in the UI, entirely.
---@param b any
function mct_section:set_hidden(b)
    if not is_boolean(b) then b = true end

    self._hidden = b

    self:ui_set_visibility()
end

function mct_section:ui_set_visibility()
    local holder = self._holder
    if is_uicomponent(holder) then
        holder:SetVisible(not self._hidden)
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

--- Get the key for this section.
-- @return string The key for this section.
function mct_section:get_key()
    return self._key
end

--- Get the @{mct_mod} that owns this section.
-- @return mct_mod The owning mct_mod for this section.
function mct_section:get_mod()
    return self._mod
end

--- Get the header text for this section.
-- Either mct_[mct_mod_key]_[section_key]_section_text, in a .loc file,
-- or the text provided using @{mct_section:set_localised_text}
-- @return string The localised text for this section, used as the title.
function mct_section:get_localised_text()
    -- default to checking the loc files
    local text = common.get_localised_string("mct_"..self:get_mod():get_key().."_"..self:get_key().."_section_text")

    if text ~= "" then
        return text
    else
        -- nothing found, check for anything supplied by `set_localised_text()`, or send the default "No text assigned"
        text = VLib.FormatText(self._text)
    end

    if not is_string(text) or text == "" then
        text = "No text assigned"
    end


    return text
end

--- create this section in the UI.
---@param this_column UIC The column UIC to pour this section into.
function mct_section:populate(this_column)
    local can_collapse = self._is_collapsible
    local key = self:get_key()
    local mod = self:get_mod()

    ---@type UIC
    local panel = mct.ui.mod_settings_panel

    local section_holder = core:get_or_create_component("mct_section_"..key, "ui/mct/layouts/resize_column", this_column)
    section_holder:SetCanResizeHeight(true)
    section_holder:Resize(this_column:Width(), 34, false)
    section_holder:SetCanResizeWidth(false)

    self._holder = section_holder

    --- different header depending on is_collapsible!
    -- first, create the section header
    local this_layout = "ui/vandy_lib/row_header"
    if not can_collapse then
        this_layout = "ui/vandy_lib/text/paragraph_header"
    end
    
    local section_header = core:get_or_create_component("section_header", this_layout, section_holder)
    self._header = section_header

    local h = 0

    -- set text & width and shit
    section_header:SetCanResizeWidth(true)
    section_header:SetCanResizeHeight(true)
    section_header:Resize(this_column:Width() * 0.95, 34, false)
    section_header:SetCanResizeWidth(false)
    section_header:SetCanResizeHeight(false)

    h = h + 34
    
    section_header:SetDockingPoint(2)
    section_header:SetState("selected")
    -- section_header:SetCanResizeWidth(false)

    -- section_header:SetDockOffset(mod_settings_box:Width() * 0.005, 0)
    
    -- local child_count = find_uicomponent(section_header, "child_count")
    -- _SetVisible(child_count, false)

    local text = self:get_localised_text()
    local tt_text = self:get_tooltip_text()

    local dy_title = find_uicomponent(section_header, "dy_title") or section_header
    dy_title:SetStateText(text)

    if tt_text ~= "" then
        _SetTooltipText(section_header, tt_text, true)
    end


    local desc = self:get_description()
    if desc ~= "" then
        local dy_desc = core:get_or_create_component("description", "ui/vandy_lib/text/dev_ui", section_holder)
        dy_desc:SetCanResizeWidth(true)
        dy_desc:SetCanResizeHeight(true)

        dy_desc:SetTextHAlign("centre")
        dy_desc:SetTextVAlign("top")

        dy_desc:Resize(this_column:Width() * 0.85, dy_desc:Height())
        dy_desc:SetCanResizeWidth(false)
        
        local tw,th = dy_desc:TextDimensionsForText(desc)
        dy_desc:ResizeTextResizingComponentToInitialSize(dy_desc:Width(), th)
        dy_desc:Resize(dy_desc:Width(), th)
        dy_desc:SetStateText(desc)
        dy_desc:SetCanResizeHeight(false)

        h = h + th
    end

    -- lastly, create all the rows and options within
    --local num_remaining_options = 0`
    -- local valid = true

    -- this is the table with the positions to the options
    -- ie. options_table["1,1"] = "option 1 key"
    -- local options_table, num_remaining_options = section_obj:get_ordered_options()

    local options_holder = core:get_or_create_component("options_holder", "ui/mct/layouts/resize_column", section_holder)
    options_holder:Resize(this_column:Width() * 0.95, options_holder:Height())
    options_holder:SetDockingPoint(8)

    for i,option_key in ipairs(self._true_ordered_options) do
        local option_obj = mod:get_option_by_key(option_key)
        get_mct().ui:new_option_row_at_pos(option_obj, options_holder, this_column:Width() * 0.95, this_column:Height() * 0.12)
    end

    -- section_holder:SetCanResizeHeight(true)

    -- section_holder:Resize(section_holder:Width(), h, false)

    -- section_holder:SetCanResizeHeight(false)

    -- section_holder:Layout()


    --- Toggles the collapsed state to what it should be 
    self:ui_set_collapsed(true)
    self:ui_set_visibility()

    return section_holder:Width(), section_holder:Height()
end

--- Set the visibility for the mct_section.
-- This works while the UI currently exists, or to set its visibility next time the panel is opened.
-- Triggers @{mct_section:uic_visibility_change} automatically.
---@param is_visible boolean True for open, false for closed.
function mct_section:set_visibility(is_visible)
    self:set_collapsed(not is_visible)
end

--- Set the title for this section.
-- Works the same as always - you can pass hard text, ie. mct_section:set_localised_text("My Section")
-- or a localised key, ie. mct_section:set_localised_text("my_section_loc_key", true)
---@param text string The localised text for this mct_section title. Either hard text, or a loc key.
function mct_section:set_localised_text(text)
    if not is_string(text) then
        err("set_localised_text() called for section ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")
        return false
    end

    self._text = VLib.HandleLocalisedText(text, "No Section Name Found")
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
        text = VLib.FormatText(self._tooltip_text)
    end

    if not is_string(text) then
        text = ""
    end

    return text
end

function mct_section:set_description(t)
    assert(is_string(t), "mct_section:set_description() called for section ["..self:get_key().."] in mct_mod ["..self:get_mod():get_key().."], but the text supplied is not a string! Returning false.")

    self._description = t
end

---@return string 
function mct_section:get_description()
    return VLib.HandleLocalisedText(self._description, "")
end

--- Assign an option to this section.
-- Automatically called through @{mct_option:set_assigned_section}.
---@param option_obj MCT.Option|string The option object to assign into this section.
function mct_section:assign_option(option_obj)
    local current_mod = self:get_mod()
    
    if is_string(option_obj) then
        ---@cast option_obj string
        -- try to get an option obj with this key
        option_obj = current_mod:get_option_by_key(option_obj)
    end

    if not option_obj or not mct:is_mct_option(option_obj) then
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

function mct_section:get_collapsible()
    return self._is_collapsible
end

function mct_section:set_is_collapsible(b)
    if is_nil(b) then b = true end
    if not is_boolean(b) then return false end

    self._is_collapsible = b

    local l_key = "MCT_SectionHeaderPressed_"..self:get_key()

    core:remove_listener(l_key)

    if b then
        core:add_listener(
            l_key,
            "ComponentLClickUp",
            function(context)
                return is_uicomponent(self._header) and context.component == self._header:Address()
            end,
            function(context)
                self:set_collapsed(not self._is_collapsed)
            end,
            true
        )
    end
end

--- Return all the options assigned to the mct_section.
---@return table<string,MCT.Option> #The table of all the options in this mct_section.
function mct_section:get_options()
    return self._options
end

return mct_section
