--- TODO a system of game interfaces that links the separate modify and query models of the game in one convenient package.

--- TODO get the Super by doing GLib.LoadModule and returning a previously created module?
-- local Super = GLib.LoadModule()

---@class Interface.Faction : Interface.Super
local defaults = {
    ---@param self Interface.Faction
    _get_func = function(self) return cm:get_faction(self._key) end
}

local Super = InterfaceSuper

---@class Interface.Faction : Interface.Super
---@field __new function: Interface.Faction
---@field __get function: FACTION_SCRIPT_INTERFACE
local FactionInterface = Super:extend("Interface.Faction", defaults)

function FactionInterface:new(key)
    
end

function FactionInterface:init()
    -- TODO once we're ready to, confirm that this faction actually exists!
end

--[[
    Money and similar resources!
--]]

--- Get the amount of money this faction currently has!
---@return number
function FactionInterface:get_money()
    local go = self:__get()
    return go:treasury()
end

function FactionInterface:set_money(n)
    local go = self:__get()
    local i = self:get_money()

    cm:treasury_mod(self:get_key(), i + n)
end

function FactionInterface:modify_money(n)
    local go = self:__get()
    cm:treasury_mod(self:get_key(), n)
end

--- TODO PR stuff

--- TODO spawn RoR
function FactionInterface:spawn_mercenary_to_pool(key, count)
    
end

--- TODO spawn agent
function FactionInterface:spawn_agent()

end

function FactionInterface:spawn_unique_agent()

end

function FactionInterface:spawn_army()

end

