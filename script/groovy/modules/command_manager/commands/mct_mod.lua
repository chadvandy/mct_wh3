--- MCT.Mod contextual commands.

---@type command_table[]
return {
    revert_to_defaults = {
        text = "Revert to Defaults",
        tooltip = "My tooltip",
        ---@param mod_obj MCT.Mod
        callback = function(mod_obj) mod_obj:revert_to_defaults() end,
    }
}