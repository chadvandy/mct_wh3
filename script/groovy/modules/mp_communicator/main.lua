---@module MP Communicator

--- 100% credit to Vanishoxyact. He built this system for easier support of long strings being passed between PC's, because there's a limit to the size of the strings that can be sent. Thanks Vanish!

--- TODO should this be loaded through the main lib?

if not core:is_campaign() then
    return
end

---@class MultiplayerCommunicator
MultiplayerCommunicator = {
    __separator = "|",
    __max_str_len = 100,

    current_event_parts = {},
}

---@param payload string
---@param callback function
function MultiplayerCommunicator:process_single_part_event(payload, callback)
    local table_func = loadstring(payload);
    if table_func then
        local table = table_func();
        callback(table);
    end
end

---@param part_number number
---@param total number
---@param payload string
---@param callback function
function MultiplayerCommunicator:process_multiple_part_event(part_number, total, payload, callback)
    out("MultiplayerEvents: processing multipart event " .. part_number .. " of " .. total .. " payload " .. payload);

    self.current_event_parts[part_number] = payload;
    if part_number == total then
        out("MultiplayerEvents: last part of multipart event received, recombining.");
        local completeEvent = "";
        for i=1, total do
            completeEvent = completeEvent .. self.current_event_parts[i];
        end
        out("MultiplayerEvents: recombine successful, processing event with full payload - " .. completeEvent);
        self:process_single_part_event(completeEvent, callback);
        self.current_event_parts = {};
    end
end

function MultiplayerCommunicator:process_event(expected_event_name, event_context, callback)
    out("MultiplayerEvents: received event - " .. event_context);
    local event_name, part_number, total_parts, payload = string.match(event_context, "(.-)" .. self.__separator .. "(%d-)/(%d-)" .. self.__separator .. "(.*)");
    if event_name and part_number and total_parts and payload then
        if event_name ~= expected_event_name then
            out("MultiplayerEvents: error processing event. Expected event name was " .. expected_event_name .. " but got " .. event_name);
            return;
        end
        self:process_multiple_part_event(tonumber(part_number), tonumber(total_parts), payload, callback);
    else
        local eventName, payload = string.match(event_context, "(.-)" .. self.__separator .. "(.*)");
        if eventName ~= expected_event_name then
            out("MultiplayerEvents: error processing event. Expected event name was " .. expected_event_name .. " but got " .. eventName);
            return;
        end
        self:process_single_part_event(payload, callback);
    end
end

--v function(eventName: string, listenerName:string, callback: function(map<string, string>))
function MultiplayerCommunicator:RegisterForEvent(event_name, listener_name, callback)
    core:add_listener(
          listener_name,
          "UITrigger",
          function(context)
              return context:trigger():starts_with(event_name .. self.__separator);
          end,
          function(context)
              self:process_event(event_name, context:trigger(), callback);
          end,
          true
    );
end

local function send_event(factionCqi, eventString)
    out("MultiplayerEvents: sending event to other player - " .. eventString);
    CampaignUI.TriggerCampaignScriptEvent(factionCqi, eventString);
end

local function create_split_event_string(eventNumber, totalEventCount, eventPayloadCapacity, tableString)
    local countLeftString = tostring(eventNumber);
    for i=string.len(countLeftString), 2 do
        countLeftString = "0" .. countLeftString;
    end
    local countRightString = tostring(totalEventCount);
    for i=string.len(countRightString), 2 do
        countRightString = "0" .. countRightString;
    end
    local eventPayloadPart = string.sub(tableString, eventPayloadCapacity * (eventNumber - 1) + 1, eventPayloadCapacity * eventNumber);
    local fullEventString = countLeftString .. "/" .. countRightString .. MultiplayerCommunicator.__separator .. eventPayloadPart;
    return fullEventString;
end

local function split_event_and_notify(eventName, factionCqi, tableString)
    local tableStringLength = string.len(tableString);
    local eventPrefix = eventName .. MultiplayerCommunicator.__separator;
    local fullEventPrefixLength = string.len(eventPrefix .. "xxx/xxx" .. MultiplayerCommunicator.__separator);
    local eventPayloadCapacity = MultiplayerCommunicator.__max_str_len - fullEventPrefixLength;
    local totalEventCount = math.ceil(tableStringLength / eventPayloadCapacity);
    out("MultiplayerEvents: splitting " .. eventName .. " event into " .. tostring(totalEventCount) .. " events - full payload is " .. tableString);

    for i=1, totalEventCount do
        local splitEvent = eventPrefix .. create_split_event_string(i, totalEventCount, eventPayloadCapacity, tableString);
        send_event(factionCqi, splitEvent);
    end
end

--- Triggers an instance of an event on all clients, passing the context of the table to each. 
---@param event_name any
---@param faction_cqi any
---@param table any
function MultiplayerCommunicator:TriggerEvent(event_name, faction_cqi, table)
    local table_str = cm:process_table_save(table)
    local eventString = event_name .. self.__separator .. table_str
    if string.len(eventString) > self.__max_str_len then
        split_event_and_notify(event_name, faction_cqi, table_str);
    else
        send_event(faction_cqi, eventString);
    end
end

function MultiplayerCommunicator:TriggerEventForCurrentFaction(event_name, table)
    MultiplayerCommunicator:TriggerEvent(event_name, cm:get_local_faction(true):command_queue_index(), table);
end

return MultiplayerCommunicator
