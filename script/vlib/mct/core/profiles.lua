--- TODO a series of profiles that users can save and use **on creation of a new campaign save only**
--- TODO figure out their creation, saving, loading, and SHARING - very importante!

---@class MCT.Profile : Class
local defaults = {
    ---@type string Localised name for this profile.
    __name = "",

    ---@type string Localised description for this profile.
    __description = "",

    ---@type table<string, table<string, any>> Table of settings for this profile; indexed by mod key, which is then a table index by option keys linked to values, ie. __mods[mod_key][option_key] = true
    __mods = {},
}

---@class MCT.Profile : Class
local Profile = VLib.NewClass("MCT.Profile", defaults)

