--- TODO the default Layout (three equal columns which can take settings and that's basically it)

---@type MCT.Page.SettingsSuperclass
local Super = get_mct():get_page_type("SettingsSuperclass")

---@class MCT.Page.SettingsThreeColumns : MCT.Page.SettingsSuperclass
local defaults = {}

---@class MCT.Page.SettingsThreeColumns : MCT.Page.SettingsSuperclass
local ThreeColumns = Super:extend("SettingsThreeColumns", defaults)

get_mct():add_new_page_type("SettingsThreeColumns", ThreeColumns)

function ThreeColumns:new(key, mod)
    VLib.Log("Creating a new SettingsThreeColumns page!")
    local o = self:__new()
    ---@cast o MCT.Page.SettingsThreeColumns
    o:init(key, mod)

    return o
end

function ThreeColumns:init(key, mod)
    Super.init(self, key, mod)

    --- TODO anything?
end

--- TODO populate ThreeColumns by creating the three_column layout
--[[
    Grab the assigned sections (if none are assigned, grab all?)
    Loop through them, call section:populate(column)
    In section:populate, call option:populate(), etc etc etc
]]

--- TODO pull "create sections and shit" here
function ThreeColumns:populate(box)
    local sections = self.assigned_sections

    if #sections == 0 then
        for _,section in pairs(self.mod_obj:get_sections()) do
            sections[#sections+1] = section
        end
    end

    local mod = self.mod_obj

    -- set the positions for all options in the mod
    mod:set_positions_for_options()

    local this_layout = core:get_or_create_component("settings_layout", "ui/mct/layouts/three_column", box)
    this_layout:Resize(box:Width(), box:Height())
    core:remove_listener("MCT_SectionHeaderPressed")
    
    for i, section_obj in ipairs(sections) do
        local section_key = section_obj:get_key()

        if not section_obj or section_obj._options == nil or next(section_obj._options) == nil then
            -- skip
        else
            -- make sure the dummy rows table is clear before doing anything
            section_obj._dummy_rows = {}

            -- first, create the section header
            local section_header = core:get_or_create_component("mct_section_"..section_key, "ui/vandy_lib/row_header", this_layout)
            --local open = true

            section_obj._header = section_header

            --- TODO set this in a Section method, mct_section:set_is_collapsible() or whatever
            core:add_listener(
                "MCT_SectionHeaderPressed",
                "ComponentLClickUp",
                function(context)
                    return context.string == "mct_section_"..section_key
                end,
                function(context)
                    local visible = section_obj:is_visible()
                    section_obj:set_visibility(not visible)
                end,
                true
            )

            -- TODO set text & width and shit
            section_header:SetCanResizeWidth(true)
            -- section_header:SetCanResizeHeight(false)
            section_header:Resize(box:Width() * 0.30, section_header:Height())
            section_header:SetDockingPoint(2)
            -- section_header:SetCanResizeWidth(false)

            -- section_header:SetDockOffset(mod_settings_box:Width() * 0.005, 0)
            
            -- local child_count = find_uicomponent(section_header, "child_count")
            -- _SetVisible(child_count, false)

            local text = section_obj:get_localised_text()
            local tt_text = section_obj:get_tooltip_text()

            local dy_title = find_uicomponent(section_header, "dy_title")
            dy_title:SetStateText(text)

            if tt_text ~= "" then
                _SetTooltipText(section_header, tt_text, true)
            end

            -- lastly, create all the rows and options within
            --local num_remaining_options = 0
            local valid = true

            -- this is the table with the positions to the options
            -- ie. options_table["1,1"] = "option 1 key"
            -- local options_table, num_remaining_options = section_obj:get_ordered_options()

            for i,option_key in ipairs(section_obj._true_ordered_options) do
                local option_obj = mod:get_option_by_key(option_key)
                get_mct().ui:new_option_row_at_pos(option_obj, this_layout) 
            end

            section_obj:uic_visibility_change(true)
        end
    end


    box:Layout()
    box:SetVisible(true)
end