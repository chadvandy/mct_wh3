--- TODO a Profile object, to store info about this profile, apply it, pull it into UI, etc. etc. etc. etc.
--- TODO Import
--- TODO Export
--- TODO Store in appdata/script/mct_profiles.lua
--- TODO Only overrides, not global edits
--- TODO port forward old profiles (check the values in profile -> compare them against default value -> if they're different, save it to NuProfile)
--- TODO make sure Profiles don't break if a mod setting changes/is removed/etc.

---@class MCT.Profile
local defaults = {
    ---@type string Localised name for this profile.
    __name = "",

    ---@type string Localised description for this profile.
    __description = "",

    ---@type table<string, table<string, any>> Table of settings for this profile; indexed by mod key, which is then a table index by option keys linked to values, ie. __mods[mod_key][option_key] = true
    __mods = {},

    ---@type string? The original author of this Profile.
    __author = nil,
}

---@class MCT.Profile : Class
---@field __new fun():MCT.Profile
local Profile = VLib.NewClass("MCT.Profile", defaults)

function Profile:new(key)
    local o = self:__new()
    o:init(key)

    return o
end

function Profile:init(key)
    if is_string(key) then
        self.__name = key
    end
end

function Profile:instantiate(o)
    setmetatable(o or {}, self)

    return o
end

function Profile:set_description(t)
    if not is_string(t) then return false end

    self.__description = t
end

function Profile:set_saved_value(mod_key, option_key, value)
    if not is_string(mod_key) then
        -- errmsg
        return
    end
    
    if not is_string(option_key) then
        -- errmsg
        return
    end
    
    if is_nil(value) then
        -- errmsg
        return
    end

    if not self.__mods[mod_key] then
        self.__mods[mod_key] = {}
    end

    self.__mods[mod_key][option_key] = value
end

function Profile:get_name()
    return self.__name
end

function Profile:get_description()
    return self.__description
end

function Profile:get_overridden_settings()
    return self.__mods
end

return Profile