--[[
    The Sync Module, in charge of multiplayer settings communications.
    
    Some assumptions we have laid out:
        - There is only a single "host", whose main purpose is to determine what settings are going to be used when starting up a new campaign, and is in charge of changing settings in an ongoing campaign, for now, for simplicity's sake.
        - Settings are cached in the frontend menu, before starting an MP campaign, and slotted into the new campaign very early on. After that point, they are saved in the save game and available to all players.
        - The "sync" behavior for starting a new campaign, in order to reduce the size and complexity of applying the settings to each user, sends only non-default values between users. So if option A, B, and C are default, we won't inform the other PC's; but if option D is a non-default value, we'll send that new value to all PC's.
    
    This module sets up the majority of the behaviors that follow those constraints and designs. We designate the host/client behaviors herein, we generate the "cache" files that have all the non-default values, and we send those values through the clients at an early point in the save.

    Some behaviors are also found in the Registry class, which handles all of the saving/loading of settings from disk and save-game.
]]

-- TODO pull in the UI-locking-stuff into this module, to keep it all in one file.
-- TODO better frontend UX; something in the panel to share who the host is and how it works.
-- TODO first-time-mp tutorial; shine the button, walk through the panel and inform how it works in detail.
--- TODO multiple-sync (probably later)

---@class MCT.Sync : Class
local defaults = {
    local_is_host = false,
    host_faction_key = "",
}

local mct = get_mct()

---@class MCT.Sync : Class
local Sync = GLib.NewClass("MCT.Sync", defaults)


--[[
    ======
    Frontend Section
    ======
--]]
function Sync:new_frontend()
    -- We are loading up the game in the frontend; we have to prepare all of our listeners to handle syncing in the frontend.
    self.local_is_host = false
    local is_in_mp_grand_campaign = false

    -- Listen for a transition into the MP Grand Campaign screen, to kick off a "refreshed" sync context.
    core:add_listener(
        "MCTSyncHost",
        "FrontendScreenTransition",
        function(context)
            return context.string == "mp_grand_campaign"
        end,
        function(context)
            -- Refresh a lot of the Sync status - clear the Registry mp-cache-file, figure out who the host is, inform the users, and start up the behaviors therein.
            is_in_mp_grand_campaign = true

            self:clear_mp_cache()
            local panel = find_uicomponent("mp_grand_campaign")

            core:get_tm():repeat_real_callback(function()
                local ready_button = find_uicomponent(panel, "ready_parent", "ready_button_frame", "button_ready")
                if ready_button and ready_button:Visible(true) then
                    core:get_tm():remove_real_callback("mct_sync_host_test")

                    -- Begin the procedures for our local host; keep track of who they are, save a registry bool, and start tracking their settings.
                    self:set_host_status_and_events()

                    -- UX to inform the players who the host is.
                    self:trigger_popup_in_frontend()
                end
            end, 10, "mct_sync_host_test")
        end,
        true
    )

    -- Reset the Sync details and close up the listeners.
    core:add_listener(
        "MCTSyncHostExit",
        "FrontendScreenTransition",
        function(context)
            -- We only want to trigger this when we're leaving the mp_grand_campaign screen.
            return is_in_mp_grand_campaign == true and context.string ~= "mp_grand_campaign"
        end,
        function(context)
            is_in_mp_grand_campaign = false

            if self.local_is_host == true then
                self.local_is_host = false

                self:clear_mp_cache()
                core:remove_listener("MCTSync_FrontendHostSettingsChanged")
            end
        end,
        true
    )
end

-- Initialization for our host player; watch their values, and save in the game's registry that they are the host.
function Sync:set_host_status_and_events()
    -- Grab if the host is local, and save the host's current faction key.
    local this_is_host = common.get_context_value("CcoFrontendRoot", "", "CampaignLobbyContext.IsLocalPlayerHost")
    local host_faction_key = common.get_context_value("CcoFrontendRoot", "", "CampaignLobbyContext.HostSlotContext.FactionRecordContextKey")

    -- TODO we need to track the host_faction_key if it changes at any point during the frontend menu, which it certainly will.
    self.local_is_host = this_is_host
    self.host_faction_key = host_faction_key
    core:svr_save_bool("mct_local_is_host", this_is_host)

    if this_is_host then
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
    else
        self:clear_mp_cache()
    end
end

-- Popup to trigger in the frontend, telling the players how it works and who the Big Boss is.
function Sync:trigger_popup_in_frontend()
    core:get_tm():real_callback(function()
        local text = ""
        if self.local_is_host then
            text = string.format("Mod Configuration Tool\n\n\nYou are the host, which means your settings will be used for the duration of the campaign. You can set them now, or edit them at any point during the campaign to apply them to other players.")
        else
            text = string.format("Mod Configuration Tool\n\n\n%s is the host, which means their settings will be used for the duration of the campaign. Confirm with them what settings you all would like, if any, before starting a new game. You will not be able to see their settings until you load the campaign, and only the host can edit.", common.get_context_value("CcoFrontendRoot", "", "CampaignLobbyContext.HostSlotContext.Name"))
        end

        GLib.TriggerPopup("mct_sync_popup", text, false)
    end, 100)
end

--[[
    ==================
    MP_Cache Section
    ==================

    Handles our mp_cache, the local file in the AppData folder that pushes data from our frontend host into the new campaign. We're only loading up the changes from default values here, as a way to reduce the size of the string passed between PCs.
--]]

-- Empty out the local "mp_cache" file in the Registry, which is simply to push data from the frontend into a new campaign.
function Sync:clear_mp_cache()
    mct:get_registry():save_host_settings(false, {})
end

-- Load up our host's settings and save them to the mp_cache Registry file.
function Sync:save_mp_cache(is_host)
    -- local ok, err = pcall(function()
    local settings = self:get_mct_data_from_local_user()       
    mct:get_registry():save_host_settings(true, settings)
    -- end) if not ok then vlog(err) end
end

---@return mct_data
---@return boolean
function Sync:load_mp_cache()
    local is_host, settings = mct:get_registry():read_host_settings()

    if is_host then
        return settings, is_host
    end
end

function Sync:is_host()
    local is_host, settings = mct:get_registry():read_host_settings()
    return is_host
end

--[[
    ==================
    Campaign Section
    ==================

    Handle our in-campaign synchronization - initial load up, and mid-game changes.

    The Host is the only person, in this version, who can edit the settings of an MP campaign. 
--]]

-- On our first load inside of a campaign, figure out who the host is and trigger all of the listeners and callbacks 
-- we need to worry about between the players.
function Sync:init_campaign()
    GLib.Log("Calling Sync.init_campaign!")

    --- Get the current host and distribute that knowledge to each PC
    if not cm:get_saved_value("mct_mp_init") then
        -- Pass the values between the players.
            -- We can tell which is the host by querying their MCT MP cache file.
        self:new_campaign()

        cm:add_pre_first_tick_callback(function()
            MultiplayerCommunicator:RegisterForEvent(
                "MctMpHostDistribution",
                "MctMpHostDistribution",
                function(context)
                    GLib.Log("[SYNC] Saving host faction key as %s", context.host_faction_key)
                    self.host_faction_key = context.host_faction_key
                    cm:set_saved_value("mct_host", self.host_faction_key)
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
    GLib.Log("== NEW CAMPAIGN SETTINGS SYNC ==")
    MultiplayerCommunicator:RegisterForEvent(
        "MctMpInitialLoad",
        "MctMpInitialLoad",
        ---@param mct_data table<string, table<string, any>>
        function(mct_data)
            GLib.Log("MctMpInitialLoad triggered. Applying host's data to current user.")

            self:apply_mct_data_to_local_user(mct_data)

            cm:set_saved_value("mct_mp_init", true)
        end
    )

    local mct_data, is_host = self:load_mp_cache()
    if is_host == true then
        MultiplayerCommunicator:TriggerEvent("MctMpInitialLoad", 0, mct_data)
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

                saved_value = mct:get_registry():get_selected_setting_for_option(option_obj)
                -- saved_value = option_obj:get_finalized_setting(true)
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