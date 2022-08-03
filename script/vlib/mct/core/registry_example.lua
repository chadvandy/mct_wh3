return {
    --- Global should hold all mod userdata, localisation, and any global-specific options.
    ["saved_mods"] = {
        ["mod_key"] = {
            ["options"] = {
                ["option_key"] = {
                    is_locked = {true, "This is locked because reason!"},
                    setting = true,
                },
            },
            ["data"] = {
                ["name"] = "Testing",
                ["description"] = "Testing",
                --- ETC.
            }
        }
    }
}