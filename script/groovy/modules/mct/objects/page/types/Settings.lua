local Super = get_mct():get_mct_page()

--- TODO do this better prolly
---@type {key:fun(), index:fun(), localised_text: fun()}
local sort_functions = GLib.LoadModule("sections", get_mct():get_path("helpers", "sort_functions"))

---@class MCT.Page.Settings
local defaults = {
    ---@type MCT.Section[]
    assigned_sections = {},

    num_columns = 3,

    _section_sort_order_function = sort_functions.index,
}

--- TODO support for side-to-side!

---@class MCT.Page.Settings : MCT.Page, Class
---@field __new fun():MCT.Page.Settings
local SettingsPage = Super:extend("Settings", defaults)

function SettingsPage:new(key, mod, num_columns, row_based)
    local o = self:__new()    
    o:init(key, mod, num_columns, row_based)

    return o
end

function SettingsPage:init(key, mod, num_columns, row_based)
    Super.init(self, key, mod)

    if not is_number(num_columns) then num_columns = 3 end
    num_columns = math.clamp(math.floor(num_columns), 1, 3)
    self.num_columns = num_columns

    if is_boolean(row_based) and row_based == true then
        self.is_row_based = true
        self.num_columns = 1
    end
end

--- Attach a settings section to this page. They will be displayed in order that they are added.
---@param section MCT.Section
function SettingsPage:assign_section_to_page(section)
    self.assigned_sections[#self.assigned_sections+1] = section
end

function SettingsPage:unassign_section(section)
    for i = #self.assigned_sections, 1, -1 do
        local this_section = self.assigned_sections[i]
        if this_section == section then
            table.remove(self.assigned_sections, i)
            break
        end
    end
end

function SettingsPage:get_assigned_sections()
    return self.assigned_sections
end

--[[ TODO instate the ui calls in relevant objects
    Grab the assigned sections (if none are assigned, grab all?)
    Loop through them, call section:populate(column)
    In section:populate, call option:populate(), etc etc etc
]]

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
function SettingsPage:set_section_sort_function(sort_func)
    if is_string(sort_func) then
        if sort_func == "key_sort" then
            self._section_sort_order_function = sort_functions.key
        elseif sort_func == "index_sort" then
            self._section_sort_order_function = sort_functions.index
        elseif sort_func == "text_sort" then
            self._section_sort_order_function = sort_functions.localised_text
        else
            GLib.Error("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided ["..sort_func.."] is an invalid string!")
            return false
        end
    elseif is_function(sort_func) then
        self._section_sort_order_function = sort_func
    else
        GLib.Error("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided isn't a string or a function!")
        return false
    end
end

--- Call the internal ._section_sort_order_function, determined by @{mct_mod:set_section_sort_function}
-- @local
---@return MCT.Section[]
function SettingsPage:sort_sections()
    -- perform the wrapped sort order function

    --- TODO grab all unassigned sections and plop them into their relative pages
    --- TODO the below should function on each page at a time
    -- TODO protect it?
    -- protect it with a pcall to catch any issues with a custom sort order func
    return self:_section_sort_order_function()
end

---@param panel UIC
function SettingsPage:populate(panel)
    local sections = self:sort_sections()

    --- TODO do the "pull into page" on the MCT.Mod level - grab any orphaned sections and toss them into main?
    --- TODO this should pull all sections that don't have a page already; right now this will pull all sections everywhere
    if #sections == 0 then
        local sorted = self:sort_sections()
        for _,key in ipairs(sorted) do
            sections[#sections+1] = self._mod_obj:get_section_by_key(key)
        end
    end

    GLib.Log("Populating a Settings page for mod %s, num sections is %d", self._mod_obj:get_key(), #sections)

    local mod = self._mod_obj

    -- set the positions for all options in the mod
    mod:set_positions_for_options()

    -- local settings_canvas = core:get_or_create_component("settings_canvas", 'ui/campaign ui/script_dummy', panel)
    -- settings_canvas:Resize(panel:Width(), panel:Height(), false)
    -- settings_canvas:SetDockingPoint(5)

    -- settings_canvas:SetCanResizeWidth(false)

    -- local layout = "ui/mct/layouts/resize_column"
    -- if self.is_row_based then
    --     layout = "ui/mct/layouts/column_three_items"
    -- end

    --- TODO horizontal view support for row-based bullshit as before
    local layout = "ui/groovy/layouts/listview"

    for i = 1, self.num_columns do
        local column = core:get_or_create_component("settings_column_"..i, layout, panel)
        column:SetCanResizeHeight(true)
        column:SetCanResizeWidth(true)
        column:Resize(panel:Width() / self.num_columns, panel:Height(), false)

        column:SetCanResizeWidth(false)

        local column_box = find_uicomponent(column, "list_clip", "list_box")

        --- 2 if num_columns = 1
        --- 1 and 3 if num_columns = 2
        --- 1 | 2 | 3 if num_columns = 3

        local docking_point = 2
        if self.num_columns == 3 then
            docking_point = i
        elseif self.num_columns == 2 then
            docking_point = i == 1 and 1 or 3
        elseif self.num_columns == 1 then
            docking_point = 2
        end

        GLib.Log("Docking point for column %d is %d", i, docking_point)

        column:SetDockingPoint(docking_point)
    end

    --- TODO cleanly split the sections between the columns
    --- TODO modder ability to set sections to columns (?)
    
    --- number of sections per column
    local per_column = math.ceil(#sections / self.num_columns)

    -- ---@type table<number, number>
    -- local column_h = {}

    -- for i = 1, self.num_columns do column_h[i] = 0 end

    local div_num = 0

    for i, section_obj in ipairs(sections) do
        local section_key = section_obj:get_key()

        local column_num = 1
        local is_last_in_column = false

        if self.num_columns == 3 then
            if i <= per_column then
                column_num = 1

                if i == per_column then
                    is_last_in_column = true
                end
            elseif i > per_column and i <= (per_column * 2) then
                column_num = 2

                if i == per_column * 2 then
                    is_last_in_column = true
                end
            else
                column_num = 3
                if i == #sections then
                    is_last_in_column = true
                end
            end
        elseif self.num_columns == 2 then
            if i <= per_column then
                column_num = 1

                if i == per_column then
                    is_last_in_column = true
                end
            else
                column_num = 2

                if i == #sections then
                    is_last_in_column = true
                end
            end
        elseif self.num_columns == 1 then
            column_num = 1

            if i == #sections then
                is_last_in_column = true
            end
        end

        GLib.Log("Assigning section %s to column %d", section_key, column_num)

        local column = find_uicomponent(panel, "settings_column_"..column_num)
        local box = find_uicomponent(column, "list_clip", "list_box")

        if not section_obj or section_obj._options == nil or next(section_obj._options) == nil then
            -- skip
        else
            section_obj:populate(box, column:Width() * 0.95, column:Height() * 0.12)

            if not is_last_in_column then
                -- create a horizontal divider!
                div_num = div_num + 1
                local div_holder = core:get_or_create_component("divider_holder_"..div_num, "ui/campaign ui/script_dummy", box)
                div_holder:Resize(box:Width(), 13)

                
                local div = core:get_or_create_component("divider", "ui/groovy/image", div_holder)
                div:SetDockingPoint(5)
                div:Resize(div_holder:Width() - 10, 13)
                div:SetImagePath("ui/skins/default/parchment_divider_length.png", 0)
                div:SetCurrentStateImageTiled(0, true)
                div:SetCurrentStateImageMargins(0, 2, 0, 2, 0)
            end
            -- column_h[column_num] = column_h[column_num] + h
        end
    end

    for i = 1, self.num_columns do 
        local column = find_uicomponent(panel, "settings_column_"..i)

        if column then
            local clip = find_uicomponent(column, "list_clip")
            local box = find_uicomponent(clip, "list_box")

            box:Layout()

            clip:Resize(column:Width(), column:Height())
            box:Resize(column:Width(), column:Height())

        end
    end
end

return SettingsPage