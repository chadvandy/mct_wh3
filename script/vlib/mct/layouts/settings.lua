local Super = get_mct()._MCT_PAGE

---@type {key:fun(), index:fun(), localised_text: fun()}
local sort_functions = VLib.LoadModule("sections", "script/vlib/mct/sort_functions/")

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
get_mct():add_new_page_type("Settings", SettingsPage)

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
            VLib.Error("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided ["..sort_func.."] is an invalid string!")
            return false
        end
    elseif is_function(sort_func) then
        self._section_sort_order_function = sort_func
    else
        VLib.Error("set_section_sort_function() called for mod ["..self:get_key().."], but the sort_func provided isn't a string or a function!")
        return false
    end
end

--- Call the internal ._section_sort_order_function, determined by @{mct_mod:set_section_sort_function}
-- @local
function SettingsPage:sort_sections()
    -- perform the wrapped sort order function

    --- TODO grab all unassigned sections and plop them into their relative pages
    --- TODO the below should function on each page at a time
    -- TODO protect it?
    -- protect it with a pcall to catch any issues with a custom sort order func
    return self:_section_sort_order_function()
end

---@param box UIC
function SettingsPage:populate(box)
    local sections = self:sort_sections()

    --- TODO do the "pull into page" on the MCT.Mod level - grab any orphaned sections and toss them into main?
    --- TODO this should pull all sections that don't have a page already; right now this will pull all sections everywhere
    if #sections == 0 then
        local sorted = self:sort_sections()
        for _,key in ipairs(sorted) do
            sections[#sections+1] = self.mod_obj:get_section_by_key(key)
        end
    end

    VLib.Log("Populating a Settings page for mod %s, num sections is %d", self.mod_obj:get_key(), #sections)

    local mod = self.mod_obj

    -- set the positions for all options in the mod
    mod:set_positions_for_options()

    ---@type UIC
    local panel = get_mct().ui.mod_settings_panel

    local settings_canvas = core:get_or_create_component("settings_canvas", 'ui/campaign ui/script_dummy', box)
    settings_canvas:Resize(panel:Width() * 0.95, panel:Height(), false)
    settings_canvas:SetDockingPoint(1)

    settings_canvas:SetCanResizeWidth(false)

    local layout = "ui/mct/layouts/column"
    if self.is_row_based then
        layout = "ui/mct/layouts/column_three_items"
    end

    for i = 1, self.num_columns do
        local column = core:get_or_create_component("settings_column_"..i, layout, settings_canvas)
        column:SetCanResizeHeight(true)
        column:Resize(settings_canvas:Width() / self.num_columns, panel:Height(), false)

        column:SetCanResizeWidth(false)

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

        VLib.Log("Docking point for column %d is %d", i, docking_point)

        column:SetDockingPoint(docking_point)
    end

    --- TODO do this at the end
    local num_dividers = self.num_columns - 1
    if num_dividers > 0 then
        for i = 1, num_dividers do
            local divider = core:get_or_create_component("divider_"..i, "ui/vandy_lib/image", settings_canvas)
            divider:SetImagePath("ui/skins/default/parchment_divider_height.png")
            -- divider:SetImageRotation(0, math.rad(90))
            divider:SetCurrentStateImageTiled(0, true)
            divider:SetCurrentStateImageMargins(0, 0, 2, 0, 2)

            local pre_column = find_uicomponent(settings_canvas, "settings_column_"..i)
    
            local cx, cy = pre_column:Position()
            local cw, ch = settings_canvas:Dimensions()
            divider:MoveTo(cx + pre_column:Width(), cy)

            divider:SetCanResizeWidth(true)
            divider:SetCanResizeHeight(true)
            divider:Resize(13, ch, false)
        end
    end

    --- TODO cleanly split the sections between the columns
    --- TODO modder ability to set sections to columns (?)
    
    --- number of sections per column
    local per_column = math.ceil(#sections / self.num_columns)

    ---@type table<number, number>
    local column_h = {}

    for i = 1, self.num_columns do column_h[i] = 0 end

    for i, section_obj in ipairs(sections) do
        local section_key = section_obj:get_key()

        local column_num = 1

        if self.num_columns == 3 then
            column_num = ((i <= per_column) and 1) or
            ((i > per_column and i <= per_column *2) and 2) or
            3
        elseif self.num_columns == 2 then
            column_num = i > per_column and 2 or 1
        elseif self.num_columns == 1 then
            column_num = 1
        end

        VLib.Log("Assigning section %s to column %d", section_key, column_num)

        local column = find_uicomponent(settings_canvas, "settings_column_"..column_num)

        if not section_obj or section_obj._options == nil or next(section_obj._options) == nil then
            -- skip
        else
            local w,h = section_obj:populate(column)
            column_h[column_num] = column_h[column_num] + h
        end
    end


    --- TODO wish there were a better way to do this
    core:get_tm():real_callback(function()
        local max_h = settings_canvas:Height()
        for i = 1, self.num_columns do
            local column = find_uicomponent(settings_canvas, "settings_column_" .. i)
            column:Resize(column:Width(), column_h[i], false)

            if column:Height() > max_h then max_h = column:Height() end

            column:SetCanResizeHeight(false)

            -- column:Layout()
        end
        -- local _,max_h = settings_canvas:Bounds()
        settings_canvas:Resize(settings_canvas:Width(), max_h, false)
    end, 10)

    -- settings_canvas:Resize(panel:Width() * 0.95, panel:Height() * 2)
end