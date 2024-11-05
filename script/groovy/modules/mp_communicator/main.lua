--- 100% credit to Vanishoxyact. He built this system for easier support of long strings being passed between PC's, because there's a limit to the size of the strings that can be sent. Thanks Vanish!

--- TODO should this be loaded through the main lib?

if not core:is_campaign() then
    return
end

---@class MP_Communicator
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


--- Take an event and it's payload, before sending it to other clients, and split it into
--- equal strings that each client will get.
--- We'll take in the payload, build a string out of it, and split it out along clear divisions, then
--- return a table of strings to send back to the TriggerEvent method.
function MultiplayerCommunicator:SplitEvent(event_name, payload)
    --- Build out a payload string for the entire payload, and then split it out smartly so we don't
    --- cut off an event in the middle of a key and cause string-query breaks.
    local retval = {}
    local payload_string = table_printer:print(payload)
    local payload_length = payload_string:len()

    local prefix = event_name .. self.__separator
    local prefix_length = prefix:len()

    local count_str = "000/000" .. self.__separator
    local count_length = count_str:len()

    -- This is the string length we need to prefix our strings with when we have multipart events to send between the computers. IE., `MyEvent|001/005|my payload here`, for the first of 5 parts of the MyEvent event.
    local full_prefix_length = prefix_length + count_length
    local remaining_length = self.__max_str_len - full_prefix_length

    -- See if we need to split this payload string into multiple chunks.
    if payload_length + prefix_length > self.__max_str_len then
        -- Our string is too long, let's split it up to the max size we can handle without
        -- cutting off any quotation marks or values.
        local remaining_string = payload_string
        local this_str, num_double

        while remaining_string ~= "" do
            -- Get the maximum amount of this string we can fit, considering our maximum length and the big event-number-splitter we're using.
            this_str = remaining_string:sub(1, remaining_length)

            -- Test to make sure we don't have a double quote cut off at any point.
            num_double = select(2, this_str:gsub("\"", "\""))

            -- We have an odd number of " in our string, let's go back and cut off before the final one.
            if num_double % 2 == 1 then
                local pos = this_str:find("\"", -1)
                this_str = this_str:sub(1, pos-1)
            end

            -- Save this partial payload and start at the end of this string.
            remaining_string = remaining_string:sub(this_str:len() + 1)
            retval[#retval+1] = this_str
        end

        -- Go through all of our payloads and add in the necessary prefix and event counts.
        -- We wait until the end of our string creation to add in the counts because we don't actually
        -- know how many different lines we'll have to spit out in the end.
        local max_count = #retval
        local this_payload

        -- Our prefix, followed by a 3-digit number, a slash, another 3-digit number, our separator, and 
        -- finally our payload string.
        -- So, `MyEvent|001/006|my_payload_here`
        -- event -> %s %03d/%03d %s <- the payload
        --     count string ^  %s <- the separator
        local payload_format = "%s%03d/%03d%s%s"

        for i = 1, max_count do
            this_payload = string.format(payload_format, prefix, i, max_count, self.__separator, retval[i])
            retval[i] = this_payload
        end
    else
        -- If it's under the max length, we're in luck, we can just spit out this one and not worry about a damn thing.
        -- TODO Should this still have the event / count string added? To simplify the conversion
        -- process when reading the events?
        retval[1] = prefix .. payload_string
    end

    return retval
end

--- Triggers an instance of an event on all clients, passing the context of the table to each. 
---@param event_name any
---@param faction_cqi any
---@param table any
function MultiplayerCommunicator:TriggerEvent(event_name, faction_cqi, table)
    -- local table_str = cm:process_table_save(table)
    -- local eventString = event_name .. self.__separator .. table_str

    local payload_strings = self:SplitEvent(event_name, table)
    local payload

    for i = 1, #payload_strings do
        payload = payload_strings[i]
        send_event(faction_cqi, payload)
    end

    -- if string.len(eventString) > self.__max_str_len then
    --     split_event_and_notify(event_name, faction_cqi, table_str);
    -- else
    --     send_event(faction_cqi, eventString);
    -- end
end

function MultiplayerCommunicator:TriggerEventForCurrentFaction(event_name, table)
    MultiplayerCommunicator:TriggerEvent(event_name, cm:get_local_faction(true):command_queue_index(), table);
end

return MultiplayerCommunicator