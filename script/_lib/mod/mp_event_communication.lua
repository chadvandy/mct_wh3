--- TODO clean this up a bit!

--- 100% credit to Vanishoxyact. He built this system for easier support of long strings being passed between PC's, because there's a limit to the size of the strings that can be sent. Thanks Vanish!

if not core:is_campaign() then
    return
end

---@class VanishMP
ClMultiplayerEvents = {};
local SEPARATOR = "|";
local MAX_EVENT_STR_LENGTH = 100;

local currentEventParts = {};

-- Receiving
local function processSinglePartEvent(payload, callback)
    local tableFunc = loadstring(payload);
    local table = tableFunc();
    callback(table);
end

local function processMultiPartEvent(partNumber, totalParts, payload, callback)
    out("MultiplayerEvents: processing multipart event " .. partNumber .. " of " .. totalParts .. " payload " .. payload);
    local partNumberValue = tonumber(partNumber, 10);
    local totalPartsNumber = tonumber(totalParts, 10);
    currentEventParts[partNumberValue] = payload;
    if partNumberValue == totalPartsNumber then
        out("MultiplayerEvents: last part of multipart event received, recombining.");
        local completeEvent = "";
        for i=1, totalPartsNumber do
            completeEvent = completeEvent .. currentEventParts[i];
        end
        out("MultiplayerEvents: recombine successful, processing event with full payload - " .. completeEvent);
        processSinglePartEvent(completeEvent, callback);
        currentEventParts = {};
    end
end

local function processReceivedEvent(expectedEventName, eventContext, callback)
    out("MultiplayerEvents: received event - " .. eventContext);
    local eventName, partNumber, totalParts, payload = string.match(eventContext, "(.-)" .. SEPARATOR .. "(%d-)/(%d-)" .. SEPARATOR .. "(.*)");
    if eventName and partNumber and totalParts and payload then
        if eventName ~= expectedEventName then
            out("MultiplayerEvents: error processing event. Expected event name was " .. expectedEventName .. " but got " .. eventName);
            return;
        end
        processMultiPartEvent(partNumber, totalParts, payload, callback);
    else
        local eventName, payload = string.match(eventContext, "(.-)" .. SEPARATOR .. "(.*)");
        if eventName ~= expectedEventName then
            out("MultiplayerEvents: error processing event. Expected event name was " .. expectedEventName .. " but got " .. eventName);
            return;
        end
        processSinglePartEvent(payload, callback);
    end
end

--v function(eventName: string, listenerName:string, callback: function(map<string, string>))
function ClMultiplayerEvents.registerForEvent(eventName, listenerName, callback)
    core:add_listener(
          listenerName,
          "UITrigger",
          function(context)
              return context:trigger():starts_with(eventName .. SEPARATOR);
          end,
          function(context)
              processReceivedEvent(eventName, context:trigger(), callback);
          end,
          true
    );
end


-- Sending
--v function(tab: any) --> string
local function GetTableSaveState(tab)
    local ret = "return {"..cm:process_table_save(tab).."}";
    return ret;
end

local function sendEvent(factionCqi, eventString)
    out("MultiplayerEvents: sending event to other player - " .. eventString);
    CampaignUI.TriggerCampaignScriptEvent(factionCqi, eventString);
end

local function createSplitEvent(eventNumber, totalEventCount, eventPayloadCapacity, tableString)
    local countLeftString = tostring(eventNumber);
    for i=string.len(countLeftString), 2 do
        countLeftString = "0" .. countLeftString;
    end
    local countRightString = tostring(totalEventCount);
    for i=string.len(countRightString), 2 do
        countRightString = "0" .. countRightString;
    end
    local eventPayloadPart = string.sub(tableString, eventPayloadCapacity * (eventNumber - 1) + 1, eventPayloadCapacity * eventNumber);
    local fullEventString = countLeftString .. "/" .. countRightString .. SEPARATOR .. eventPayloadPart;
    return fullEventString;
end

local function splitEventAndNotify(eventName, factionCqi, tableString)
    local tableStringLength = string.len(tableString);
    local eventPrefix = eventName .. SEPARATOR;
    local fullEventPrefixLength = string.len(eventPrefix .. "xxx/xxx|");
    local eventPayloadCapacity = MAX_EVENT_STR_LENGTH - fullEventPrefixLength;
    local totalEventCount = math.ceil(tableStringLength / eventPayloadCapacity);
    out("MultiplayerEvents: splitting " .. eventName .. " event into " .. tostring(totalEventCount) .. " events - full payload is " .. tableString);

    for i=1, totalEventCount do
        local splitEvent = eventPrefix .. createSplitEvent(i, totalEventCount, eventPayloadCapacity, tableString);
        sendEvent(factionCqi, splitEvent);
    end
end

--v function(eventName: string, factionCqi: CA_CQI, table: map<string, string>)
function ClMultiplayerEvents.notifyEvent(eventName, factionCqi, table)
    local tableString = GetTableSaveState(table)
    local eventString = eventName .. SEPARATOR .. tableString
    if string.len(eventString) > MAX_EVENT_STR_LENGTH then
        splitEventAndNotify(eventName, factionCqi, tableString);
    else
        sendEvent(factionCqi, eventString);
    end
end

function ClMultiplayerEvents.notifyEventForCurrentFaction(eventName, table)
    ClMultiplayerEvents.notifyEvent(eventName, cm:get_local_faction(true):command_queue_index(), table);
end