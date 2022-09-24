--- TODO import all MP support systems into here, to keep it easier to navigate!

---@class MCT.Sync : Class
local defaults = {
    local_is_host = false,
}

local mct = get_mct()

---@class MCT.Sync : Class
local Sync = VLib.NewClass("MCT.Sync", defaults)

--- TODO read who the host is in frontend UI (listen for going into the host campaign screen and save a bool there, instead of scrubbing UI)
function Sync:new_frontend()
    self.local_is_host = false

    core:add_listener(
        "MCTSyncHost",
        "FrontendScreenTransition",
        true,
        function(context)
            if not self.local_is_host then
                if context.string == "mp_campaign_host" then
                    self.local_is_host = true
                end
            else
                if context.string ~= "mp_grand_campaign" then
                    self.local_is_host = false
                end
            end

            if context.string == "mp_grand_campaign" then
                core:svr_save_bool("mct_local_is_host", self.local_is_host)
            end
        end,
        true
    )
end

--- TODO initial sync on new game
--- TODO only handle campaign settings
--- TODO multiple-sync (probably later)
--- TODO save campaign data in global registry, w/ bool for "is_multiplayer" and faction key for "mct_host" (if needed)

--- TODO if first load, get the host and then sync the settings on LoadingGame
--- TODO if reload, get the settings from the save game file on LoadingGame
function Sync:init_campaign()
    VLib.Log("Calling Sync.init_campaign!")
    --- Get the current host and distribute that knowledge to each PC
    if not cm:get_saved_value("mct_mp_init") then
        cm:add_pre_first_tick_callback(function()
            MultiplayerCommunicator:RegisterForEvent(
                "MctMpHostDistribution",
                "MctMpHostDistribution",
                function(context)
                    VLib.Log("[SYNC] Saving host faction key as %s", context.host_faction_key)
                    self.host_faction_key = context.host_faction_key
                    cm:set_saved_value("mct_host", self.host_faction_key)

                    --- Then, run through new_campaign which will distribute the current settings to each PC
                    self:new_campaign(self.host_faction_key)
                end
            )
            if core:svr_load_bool("mct_local_is_host") == true then
                VLib.Log("Local is host!")
                local this_faction = cm:get_local_faction_name(true)

                MultiplayerCommunicator:TriggerEvent("MctMpHostDistribution", 0, {host_faction_key = this_faction})
            end
        end)
    else
        --- TODO reload, I think we just use Registry:load_game() here and set the necessary MP settings we need to set (ie. one-person-edit for now)
    end
end

--- TODO a way to get the current host 
--- -> on their PC, get their settings
--- -> then use MultiplayerCommunicator to send it to all others
function Sync:new_campaign(host_faction_key)
    MultiplayerCommunicator:RegisterForEvent(
        "MctMpInitialLoad",
        "MctMpInitialLoad",
        ---@param mct_data table<string, table<string, any>>
        function(mct_data)
            VLib.Log("MctMpInitialLoad triggered!")
            for mod_key, mod_data in pairs(mct_data) do
                local mod_obj = mct:get_mod_by_key(mod_key)
                VLib.Log("\tIn mod %s", mod_key)

                if mod_obj then
                    for option_key, option_data in pairs(mod_data) do
                        VLib.Log("\t\tIn option %s", option_key)
                        local option_obj = mod_obj:get_option_by_key(option_key)

                        if option_obj then
                            VLib.Log("\t\tSetting option %s to %s", option_key, tostring(option_data))
                            option_obj:set_finalized_setting(option_data, true)
                        end
                    end
                end
            end
        end
    )

    if cm.game_interface:model():faction_is_local(host_faction_key) then
        local t = {}

        local all_mods = mct:get_mods()
        for mod_key, mod_obj in pairs(all_mods) do
            t[mod_key] = {}

            local options = mod_obj:get_options()

            for option_key, option_obj in pairs(options) do
                
                -- don't send local-only settings to both
                if option_obj:is_global() == false then
                    t[mod_key][option_key] = option_obj:get_finalized_setting()
                end
            end
        end

        MultiplayerCommunicator:TriggerEvent("MctMpInitialLoad", 0, t)
    end
end


return Sync