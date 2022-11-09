--- TODO import all MP support systems into here, to keep it easier to navigate!

---@class MCT.Sync : Class
local defaults = {
    local_is_host = false,
}

local mct = get_mct()

---@class MCT.Sync : Class
local Sync = VLib.NewClass("MCT.Sync", defaults)

function Sync:new_frontend()
    self.local_is_host = false

    core:add_listener(
        "MCTSyncHost",
        "FrontendScreenTransition",
        function(context)
            return context.string == "mp_grand_campaign"
        end,
        function(context)
            local panel = find_uicomponent("mp_grand_campaign")

            core:get_tm():repeat_real_callback(function()
                local ready_button = find_uicomponent(panel, "ready_parent", "ready_button_frame", "button_ready")
                if ready_button and ready_button:Visible(true) then
                    core:get_tm():remove_real_callback("mct_sync_host_test")

                    self.local_is_host = common.get_context_value("CcoFrontendRoot", "", "CampaignLobbyContext.IsLocalPlayerHost")
                    core:svr_save_bool("mct_local_is_host", self.local_is_host)

                    core:get_tm():real_callback(function()
                        local text = "Mod Configuration Tool\n\n"
                        if self.local_is_host then
                            text = text .. "\nYou are the host, which means your settings will be used for the duration of the campaign. You can set them now, or edit them at any point during the campaign to apply them to other players."
                        else
                            text = text .. "\n" .. common.get_context_value("CcoFrontendRoot", "", "HostSlotContext.Name") .. " is the host, which means their settings will be used for the duration of the campaign. Confirm with them what settings you all would like, if any, before starting a new game. You will not be able to see their settings until you load the campaign, and only the host can edit."
                        end
    
                        VLib.TriggerPopup("mct_sync_popup", text, false)
                    end, 100)
                end
            end, 10, "mct_sync_host_test")
        end,
        true
    )
end

--- TODO multiple-sync (probably later)
--- TODO save campaign data in global registry, w/ bool for "is_multiplayer" and faction key for "mct_host" (if needed)

--- on first load, get the host and then sync the settings on LoadingGame
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
    end

    --- Trigger the listeners for pulling in the new settings from the host.
    self:assign_settings_from_host()
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

            self:apply_mct_data_to_local_user(mct_data)

            cm:set_saved_value("mct_mp_init", true)
        end
    )

    if cm.game_interface:model():faction_is_local(host_faction_key) then
        local t = self:get_mct_data_from_local_user()
        MultiplayerCommunicator:TriggerEvent("MctMpInitialLoad", 0, t)
    end
end

---@alias mct_data table<string, table<string, any>>

--- RegisterForEvent for clients
function Sync:assign_settings_from_host()
    MultiplayerCommunicator:RegisterForEvent(
        "MctMpFinalized",
        "MctMpFinalized",
        ---@param mct_data mct_data
        function(mct_data)
            VLib.Log("MctMpFinalized called, saving settings from host!")

            self:apply_mct_data_to_local_user(mct_data)

            VLib.Log("Proper settings retrieved from host, saving and finalizing!")
            mct.registry:save()
            core:trigger_custom_event("MctFinalized", {["mct"] = mct, ["mp_sent"] = false})
        end
    )
end

--- TriggerEvent from host
function Sync:distribute_finalized_settings()
    -- communicate to both clients that this is happening!
    local mct_data = self:get_mct_data_from_local_user()
    MultiplayerCommunicator:TriggerEvent("MctMpFinalized", 0, mct_data)
end

---@param mct_data mct_data
function Sync:apply_mct_data_to_local_user(mct_data)
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

---@return mct_data
function Sync:get_mct_data_from_local_user()
    local mct_data = {}
    local all_mods = mct:get_mods()
    for mod_key, mod_obj in pairs(all_mods) do
        vlog("Looping through mod obj ["..mod_key.."]")
        mct_data[mod_key] = {}
        local all_options = mod_obj:get_options()

        for option_key, option_obj in pairs(all_options) do
            if not option_obj:is_global() then
                vlog("Looping through option obj ["..option_key.."]")
                mct_data[mod_key][option_key] = mct.registry:get_selected_setting_for_option(option_obj)

                vlog("Setting: "..tostring(mct_data[mod_key][option_key]))
            end
        end
    end

    return mct_data
end

return Sync