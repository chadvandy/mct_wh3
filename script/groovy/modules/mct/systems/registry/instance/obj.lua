--- Individual RegistryInstance object.

---@alias RegistryData table<string, {settings: table, data: table}>

---@class MCT.RegistryInstance
local obj = {
    data = {
        saved_mods = {},
    },
}

--- Individual Registry, for various purposes - holding global values, campaign-specific values each campaign, profile values, etc.
---@class MCT.RegistryInstance : Class
local RegistryInstance = GLib.NewClass("MCT.Registry", obj)

function RegistryInstance:new()
    local o = self:__new()
    return o
end

function RegistryInstance:initialize_mod_data(mod_key)
    self.data.saved_mods[mod_key] = {
        settings = {},
        data = {},
    }
end

function RegistryInstance:get_mod_data(mod_key)
    return self.data.saved_mods[mod_key]
end

function RegistryInstance:get_setting_data(mod_key, option_key)
    -- return self:get_mod_data(mod_key)
    if not self:get_mod_data(mod_key) then
        return
    end

    return self:get_mod_data(mod_key).settings[option_key]
end

function RegistryInstance:clear_mod_data(mod_key)
    self.data.saved_mods[mod_key] = nil
end

function RegistryInstance:is_mod_data_empty(mod_key)
    return next(self:get_mod_data(mod_key).settings) == nil
end

function RegistryInstance:save_setting_value(mod_key, option_key, value)
    if not self:get_mod_data(mod_key) then
        self:initialize_mod_data(mod_key)
    end

    self:get_setting_data(mod_key, option_key).value = value
end

function RegistryInstance:clear_setting_value(mod_key, option_key)
    if not self:get_mod_data(mod_key) then
        return
    end

    if not self:get_setting_data(mod_key, option_key) then
        return
    end

    self:get_setting_data(mod_key, option_key).value = nil
end

function RegistryInstance:get_setting_value(mod_key, option_key)
    if not self:get_mod_data(mod_key) then
        return
    end

    if not self:get_setting_data(mod_key, option_key) then
        return
    end

    return self:get_setting_data(mod_key, option_key).value
end

return RegistryInstance