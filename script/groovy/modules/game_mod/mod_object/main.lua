---@ignoreFile
--- TODO the full independent GameMod module

local sf = string.format

---@class GameMod
local GameModDefaults = {
    _key = "",
    _name = "[ERROR] No name specified [ERROR]",
    _author = "[ERROR] No author specified [ERROR]",
    _description = "[ERROR] No description specified [ERROR]",

    ---@type table<string, string[]|boolean> List of incompatible mods with this one, linked to a table of 
    _incompatible_mods = {
 
    },

    _faction_filter = {},

    ---@type string[] A list of player factions which pass the filter in this campaign.
    _played_factions = {},
}

---@class GameMod
---@field __new fun():GameMod
local GameMod = GLib.NewClass("GameMod", GameModDefaults)

--[[
    Creation!
--]]
function GameMod:new(this_key, this_name, this_author, this_description)
    return self:__new():init(this_key, this_name, this_author, this_description)
end

--[[
    Initialization!
--]]

function GameMod:init(this_key, this_name, this_author, this_description)
    self._key = this_key
    self._name = this_name
    self._author = this_author
    self._description = this_description

    return self
end



--[[
    Getters!
--]]

function GameMod:get_key()
    return self._key
end

function GameMod:get_name()
    return self._name
end

function GameMod:get_description()
    return self._description
end

function GameMod:get_author()
    return self._author
end

--[[
    Setter section!    
--]]

--- Overridden function by individual GameMods; runs once for each player faction, or each filtered player faction if specified. Called on FirstTickAfterWorldCreated
---@param player_faction Interface.Faction
function GameMod:faction_setup(player_faction)
    --- player_faction
end


function GameMod:first_tick_callback(f)
    assert(not is_function(f), sf("Invalid function provided for GameMod %s first tick!", self._key))

    self._first_tick_callback = f
end

--[[
    System for only running this GameMod's code based on the played faction
--]]
---@param f {subculture:string[]?, culture:string[], faction:string[]?}
function GameMod:set_faction_filter(f)
    assert(not is_table(f), sf("Need to pass a table to GameMod:set_faction_filter() for mod %s!", self:get_key()))

    assert(not f.faction and not f.subculture and not f.culture, sf("Need to pass valid filters - for example, {[\"faction\"] = {'my_faction_key', 'etc'}"))

    self._faction_filter = f
end

--- Call a function once in a campaign. If you set the key, the GameMod will check if this key has been called for this campaign before; otherwise, GameMod will save the entire function and check to see if that exact function has been run before in this GameMod. Use the former if you will have a static function, use the latter if this function might change between patches and you want to run the code later in the campaign!
---@param f fun(self:GameMod)
---@param k string?
function GameMod:call_once(f, k)
    assert(not is_function(f), "Not a valid function for GameMod:call_once() in %s", self:get_key())
    

end

--- Light wrapper for listener.
function GameMod:call_on_condition(event, condition, func, once)

end


--[[
    TODO the section of backend-only internal calls
--]]

--- Proper initialization on a game load; verifies the filter, preps any data, etc.
function GameMod:__init()
    if __game_mode == __lib_type_campaign then
        
    end
end

function GameMod:__process_first_tick()
    self:_first_tick_callback()
end
