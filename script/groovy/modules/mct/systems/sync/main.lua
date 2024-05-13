    --[[
        TODO a quick refresh/rewrite for how MP sync works.

            In frontend:
                Clear the MCT register cache on joining new MP campaign.
                The "Host" selects the settings they want to set.
                    LATER: A way to share them here - maybe a file they can send over and load locally.
                The Host's settings are temporarily saved in an MCT register cache, w/ "new_mp_campaign" or something as its tag.
                That's pretty much it.
            Starting campaign:
                The users' PCs all check the local new_mp_campaign registry cache, and query if they're the host or not.
                Save on each PC the host's faction key.
                As early as possible, send from host to each user the list of NON-DEFAULT SETTINGS ONLY.
                    Set the saved values for each setting to the host-set values.
                Save these settings into the save game.
            Continuing:
                Read/Write is done through the save game at this point; locality doesn't matter anymore.
                Leave changing settings for Host only, for simplicity.

    ]]


---@class MCT.Sync : Class
local defaults = {
    local_is_host = false,
}

local mct = get_mct()

---@class MCT.Sync : Class
local Sync = GLib.NewClass("MCT.Sync", defaults)

function Sync:new_frontend()
    self.local_is_host = false

    core:add_listener(
        "MCTSyncHost",
        "FrontendScreenTransition",
        function(context)
            return context.string == "mp_grand_campaign"
        end,
        function(context)
            self:clear_mp_cache()

            local panel = find_uicomponent("mp_grand_campaign")

            core:get_tm():repeat_real_callback(function()
                local ready_button = find_uicomponent(panel, "ready_parent", "ready_button_frame", "button_ready")
                if ready_button and ready_button:Visible(true) then
                    core:get_tm():remove_real_callback("mct_sync_host_test")

                    self:set_is_host(common.get_context_value("CcoFrontendRoot", "", "CampaignLobbyContext.IsLocalPlayerHost"))

                    self:trigger_popup_in_frontend()
                end
            end, 10, "mct_sync_host_test")
        end,
        true
    )

    core:add_listener(
        "MCTSyncHostExit",
        "FrontendScreenTransition",
        function(context)
            return context.string ~= "mp_grand_campaign"
        end,
        function(context)
            if self.local_is_host == true then
                self.local_is_host = false

                self:clear_mp_cache()
                core:remove_listener("MCTSync_FrontendHostSettingsChanged")
            end
        end,
        true
    )
end

function Sync:clear_mp_cache()
    mct:get_registry():save_host_settings(false, {})
end

function Sync:save_mp_cache()
    local ok, err = pcall(function()
    local settings = self:get_mct_data_from_local_user()
    mct:get_registry():save_host_settings(true, settings)
    end) if not ok then vlog(err) end
end

function Sync:set_is_host(bIsHost)
    self.local_is_host = bIsHost
    core:svr_save_bool("mct_local_is_host", bIsHost)

    if bIsHost then
        self:save_mp_cache()

        -- start up a listener to save the MP cache for this person if they change any settings
            -- and cancel that listener if we leave this state.
        core:add_listener(
            "MCTSync_FrontendHostSettingsChanged",
            "MctFinalized",
            true,
            function(context)
                self:save_mp_cache()
            end,
            true
        )
    end
end

function Sync:load_mp_cache()
    local is_host, settings = mct:get_registry():read_host_settings()

    if is_host then
        return settings
    end
end

function Sync:trigger_popup_in_frontend()
    core:get_tm():real_callback(function()
        local text = ""
        if self.local_is_host then
            text = string.format("Mod Configuration Tool\n\n\nYou are the host, which means your settings will be used for the duration of the campaign. You can set them now, or edit them at any point during the campaign to apply them to other players.")
        else
            text = string.format("Mod Configuration Tool\n\n\n%s is the host, which means their settings will be used for the duration of the campaign. Confirm with them what settings you all would like, if any, before starting a new game. You will not be able to see their settings until you load the campaign, and only the host can edit.", common.get_context_value("CcoFrontendRoot", "", "HostSlotContext.Name"))
        end

        GLib.TriggerPopup("mct_sync_popup", text, false)
    end, 100)
end

--- TODO multiple-sync (probably later)
--- TODO save campaign data in global registry, w/ bool for "is_multiplayer" and faction key for "mct_host" (if needed)

--- on first load, get the host and then sync the settings on LoadingGame
function Sync:init_campaign()
    GLib.Log("Calling Sync.init_campaign!")
    --- Get the current host and distribute that knowledge to each PC
    if not cm:get_saved_value("mct_mp_init") then
        cm:add_pre_first_tick_callback(function()
            MultiplayerCommunicator:RegisterForEvent(
                "MctMpHostDistribution",
                "MctMpHostDistribution",
                function(context)
                    GLib.Log("[SYNC] Saving host faction key as %s", context.host_faction_key)
                    self.host_faction_key = context.host_faction_key
                    cm:set_saved_value("mct_host", self.host_faction_key)

                    --- Then, run through new_campaign which will distribute the current settings to each PC
                    self:new_campaign()
                end
            )

            if core:svr_load_bool("mct_local_is_host") == true then
                mct:set_mode("campaign", true)
                GLib.Log("Local is host!")
                local this_faction = cm:get_local_faction_name(true)

                MultiplayerCommunicator:TriggerEvent("MctMpHostDistribution", 0, {host_faction_key = this_faction})
            end
        end)
    end

    --- Trigger the listeners for pulling in the new settings from the host.
    self:listen_to_assign_settings_from_host()
end

--- TODO a way to get the current host 
--- -> on their PC, get their settings
--- -> then use MultiplayerCommunicator to send it to all others
function Sync:new_campaign()
    MultiplayerCommunicator:RegisterForEvent(
        "MctMpInitialLoad",
        "MctMpInitialLoad",
        ---@param mct_data table<string, table<string, any>>
        function(mct_data)
            GLib.Log("MctMpInitialLoad triggered!")

            self:apply_mct_data_to_local_user(mct_data)

            cm:set_saved_value("mct_mp_init", true)
        end
    )

    local is_host, t = self:load_mp_cache()
    if is_host == true then
        MultiplayerCommunicator:TriggerEvent("MctMpInitialLoad", 0, t)
    end

    -- if cm.game_interface:model():faction_is_local(host_faction_key) then
    --     -- local t = self:get_mct_data_from_local_user()
    -- end
end

---@alias mct_data table<string, table<string, any>>

--- RegisterForEvent for clients
function Sync:listen_to_assign_settings_from_host()
    MultiplayerCommunicator:RegisterForEvent(
        "MctMpFinalized",
        "MctMpFinalized",
        ---@param mct_data mct_data
        function(mct_data)
            GLib.Log("MctMpFinalized called, saving settings from host!")

            self:apply_mct_data_to_local_user(mct_data)

            GLib.Log("Proper settings retrieved from host, saving and finalizing!")
            mct:get_registry():save()
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
    local all_mods = mct:get_mods()
    local all_options
    local mod_data, option_data

    for mod_key, mod_obj in pairs(all_mods) do
        all_options = mod_obj:get_options()
        mod_data = mct_data[mod_key]

        for option_key, option_obj in pairs(all_options) do
            if not option_obj:is_global() and not option_obj:get_mp_disabled() then
                option_data = not is_nil(mod_data) and mod_data[option_key]

                if not is_nil(option_data) then
                    option_obj:set_finalized_setting(option_data, true)
                else
                    option_obj:set_finalized_setting(option_obj:get_default_value(false), true)
                end
            end
        end
    end
end

---@return mct_data
function Sync:get_mct_data_from_local_user()
    local mct_data = {}
    local all_mods = mct:get_mods()
    local all_options, mod_data, any, saved_value, default_value

    vlog("Getting MCT data from local user.")

    for mod_key, mod_obj in pairs(all_mods) do
        vlog("Looping through mod obj ["..mod_key.."]")
        
        any = false
        mod_data = {}

        all_options = mod_obj:get_options()

        for option_key, option_obj in pairs(all_options) do
            if not option_obj:is_global() and not option_obj:get_mp_disabled() then
                vlog("Looping through option obj ["..option_key.."]")

                -- saved_value = mct:get_registry():get_selected_setting_for_option(option_obj)
                saved_value = option_obj:get_finalized_setting(true)
                default_value = option_obj:get_default_value(false)

                vlog(string.format("\tCurrently finalized setting is %s\n\tDefault value is %s", tostring(saved_value), tostring(default_value)))

                -- only share non-default values.
                if saved_value ~= default_value then
                    mod_data[option_key] = saved_value
                    any = true

                    vlog(string.format("Saving setting for option %s!", option_key))
                end
            end
        end

        if any == true then mct_data[mod_key] = mod_data end
    end

    return mct_data
end

return Sync