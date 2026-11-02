local Super = get_mct():get_mct_page_class()

--- TODO do this better prolly
---@type {key:fun(), index:fun(), localised_text: fun()}
local sort_functions = GLib.LoadModule("sections", get_mct():get_path("helpers", "sort_functions"))

---@class MCT.Page.Settings
local defaults = {
    ---@type MCT.Section[]
    assigned_sections = {},

    num_columns = 2,

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

function SettingsPage:remove()
    local mod = self:get_mod()

    if mod:get_default_settings_page() == self then
        -- we can't remove the default settings page!
        GLib.Error("Trying to remove settings page [%s] for mod [%s], but it's the default settings page! Cannot remove it! Use `mct_mod:set_default_settings_page()` first!", self:get_key(), mod:get_key())
        return
    end

    -- remove the page from the mod
    mod:remove_settings_page(self)

    -- kill it in the UI
    local row_uic = self:get_row_uic()

    if is_uicomponent(row_uic) then
        row_uic:Destroy()
    end

    -- trash collect
    self = nil
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

--- Split the sorted sections into this page's columns. Pinned sections go to their column, clamped to the column count. The rest are split
--- evenly by count in sort order, and empty sections still count so existing layouts keep their split.
---@param sections MCT.Section[] The sorted sections on this page.
---@return MCT.Section[][] #The sections to draw in each column, in sort order. Sections without options are left out.
function SettingsPage:assign_columns(sections)
    local num_unpinned = 0
    for _, section_obj in ipairs(sections) do
        if not section_obj:get_column() then num_unpinned = num_unpinned + 1 end
    end

    local per_column = math.ceil(num_unpinned / self.num_columns)

    local columns = {}
    for i = 1, self.num_columns do columns[i] = {} end

    local unpinned_index = 0
    for _, section_obj in ipairs(sections) do
        local column_num = section_obj:get_column()
        if column_num then
            if column_num > self.num_columns then
                GLib.Log("Section %s is pinned to column %d, but this page only has %d columns. Using the last column.", section_obj:get_key(), column_num, self.num_columns)
                column_num = self.num_columns
            end
        else
            unpinned_index = unpinned_index + 1
            column_num = math.ceil(unpinned_index / per_column)
        end

        if next(section_obj:get_options()) ~= nil then
            local column_sections = columns[column_num]
            column_sections[#column_sections+1] = section_obj
        end
    end

    return columns
end

--- The width for rows in a column. Rows stop at the column's scrollbar, so their content keeps the same inset on the right as on the left.
---@param column UIC The column's list view.
---@return number
function SettingsPage:get_row_width(column)
    local scrollbar = find_uicomponent(column, "vslider")
    if not scrollbar then return column:Width() end

    -- the scrollbar docks to the right edge, pulled in by its dock offset
    local offset_x = scrollbar:GetDockOffset()
    return column:Width() - scrollbar:Width() + offset_x
end

---@param panel UIC
function SettingsPage:populate(panel)
    local sections = self:sort_sections()
    local ui = get_mct():get_ui()
    local spacing = ui:get_spacing()

    --- TODO do the "pull into page" on the MCT.Mod level - grab any orphaned sections and toss them into main?
    --- TODO this should pull all sections that don't have a page already; right now this will pull all sections everywhere
    if #sections == 0 then
        local all = self._mod_obj:get_sections()
        for key,section in pairs(all) do
            if not section:get_page() then
                sections[#sections+1] = section
                section:assign_to_page(self)
            end
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

        -- top padding, so the first section isn't flush against the page title
        ui:create_spacer(column_box, "padding_top", column:Width(), spacing.column_pad_top)
    end

    local div_num = 0

    -- equal space above and below each divider between sections. The last row above already brings its own bottom padding.
    local div_above = math.max(0, spacing.section_gap - spacing.row_pad_y)

    for column_num, column_sections in ipairs(self:assign_columns(sections)) do
        local column = find_uicomponent(panel, "settings_column_"..column_num)
        local box = find_uicomponent(column, "list_clip", "list_box")
        local row_w = self:get_row_width(column)

        for i, section_obj in ipairs(column_sections) do
            GLib.Log("Assigning section %s to column %d", section_obj:get_key(), column_num)

            -- rows span the column up to its scrollbar and inset their own content, since the column's list puts every child at its left edge
            section_obj:populate(box, row_w, column:Height() * 0.12)

            if i < #column_sections then
                -- create a horizontal divider!
                div_num = div_num + 1

                local div_holder = ui:create_spacer(box, "divider_holder_"..div_num, row_w, div_above + spacing.divider_h + spacing.section_gap)
                local div = ui:create_divider_image(div_holder, row_w - spacing.inset_x * 2)
                div:SetDockingPoint(2)
                div:SetDockOffset(0, div_above)
            end
        end
    end

    for i = 1, self.num_columns do 
        local column = find_uicomponent(panel, "settings_column_"..i)

        if column then
            local clip = find_uicomponent(column, "list_clip")
            local box = find_uicomponent(clip, "list_box")

            ui:create_spacer(box, "padding_bottom", column:Width(), spacing.column_pad_bottom)

            -- don't resize children. They're already sized for the column, and scaling them up from the template size stretches the dividers.
            clip:Resize(column:Width(), column:Height(), false)
            box:Resize(column:Width(), column:Height(), false)

            box:Layout()
        end
    end

    self:OnPopulate(panel)
end

return SettingsPage