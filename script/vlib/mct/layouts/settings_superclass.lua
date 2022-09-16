--- TODO unused superclass for all settings-type layouts
local Super = get_mct()._MCT_PAGE

---@class MCT.Page.SettingsSuperclass : MCT.Page
local defaults = {
    ---@type MCT.Section[]
    assigned_sections = {},

    num_columns = 3,
}

---@class MCT.Page.SettingsSuperclass : MCT.Page
local SettingsSuperclass = Super:extend("SettingsSuperclass", defaults)
get_mct():add_new_page_type("SettingsSuperclass", SettingsSuperclass)

function SettingsSuperclass:new(key, mod, num_columns)
    local o = self:__new()
    ---@cast o MCT.Page.SettingsSuperclass

    
    o:init(key, mod, num_columns)

    return o
end

function SettingsSuperclass:init(key, mod, num_columns)
    Super.init(self, key, mod)

    if not is_number(num_columns) then num_columns = 3 end
    num_columns = math.clamp(math.floor(num_columns), 1, 3)
    self.num_columns = num_columns
end

--- Attach a settings section to this page. They will be displayed in order that they are added.
---@param section MCT.Section
function SettingsSuperclass:assign_section_to_page(section)
    self.assigned_sections[#self.assigned_sections+1] = section
end

function SettingsSuperclass:unassign_section(section)
    for i = #self.assigned_sections, 1, -1 do
        local this_section = self.assigned_sections[i]
        if this_section == section then
            table.remove(self.assigned_sections, i)
            break
        end
    end
end

function SettingsSuperclass:get_assigned_sections()
    return self.assigned_sections
end

--[[ TODO instate the ui calls in relevant objects
    Grab the assigned sections (if none are assigned, grab all?)
    Loop through them, call section:populate(column)
    In section:populate, call option:populate(), etc etc etc
]]

---@param box UIC
function SettingsSuperclass:populate(box)
    local sections = self.assigned_sections

    --- TODO this should pull all sections that don't have a page already; right now this will pull all sections everywhere
    --- TODO properly order them!
    if #sections == 0 then
        local sorted = self.mod_obj:sort_sections(self)
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

    for i = 1, self.num_columns do
        local column = core:get_or_create_component("settings_column_"..i, "ui/mct/layouts/column", settings_canvas)
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

    local column_h = {}

    for i = 1, self.num_columns do column_h[i] = 0 end

    for i, section_obj in ipairs(sections) do
        local section_key = section_obj:get_key()

        local column_num = 1

        if self.num_columns == 3 then
            column_num = i <= per_column and 1 or
            i > per_column and i <= per_column *2 and 2 or
            i >= per_column *2 and 3
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