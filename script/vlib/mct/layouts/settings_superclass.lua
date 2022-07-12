--- TODO unused superclass for all settings-type layouts
local Super = get_mct()._MCT_PAGE

---@class MCT.Page.SettingsSuperclass : MCT.Page
local defaults = {
    ---@type MCT.Section[]
    assigned_sections = {},
}

---@class MCT.Page.SettingsSuperclass : MCT.Page
local SettingsSuperclass = Super:extend("SettingsSuperclass", defaults)
get_mct():add_new_page_type("SettingsSuperclass", SettingsSuperclass)

function SettingsSuperclass:new(key, mod)
    local o = self:__new()

    ---@cast o MCT.Page.SettingsSuperclass
    o:init(key, mod)

    return o
end

function SettingsSuperclass:init(key, mod)
    Super.init(self, key, mod)
end

--- Attach a settings section to this page. They will be displayed in order that they are added.
---@param section MCT.Section
function SettingsSuperclass:assign_section_to_page(section)
    self.assigned_sections[#self.assigned_sections+1] = section
end