---@ignoreFile
--- TODO a parent class for each interface, to make getting ez

---@class Interface.Super
local defaults = {
    ---@type string The key to get this game object.
    _key = "",
    _game_object = nil,

    --- The individual getter function for this game object. Should never be directly called - use __get instead!
    ---@return any
    _get_func = function() return nil end,
}

---@class Interface.Super
---@field __new fun():Interface.Super
InterfaceSuper = GLib.NewClass("InterfaceSuper", defaults)

--- TODO should NEVER be called!!!?!?!?!
function InterfaceSuper:new()
    assert(nil, "This function should NEVER be called!")
    return nil
end

--- TODO verify that this is a valid game object; if not, abort!
function InterfaceSuper:init()
    if not cm.model_is_created then
        function self:first_tick_callback()
            self:init()
        end
    else
        local go = self:__get()
    end
end

function InterfaceSuper:get_key()
    return self._key
end

function InterfaceSuper:first_tick_callback()

end

--- Called every game tick to clear unhealthy internals. 
function InterfaceSuper:__clear()
    self._game_object = nil
end

--- TODO cache the return value and empty it out after a tick?
---@return userdata #Get the script interface for this game object!
function InterfaceSuper:__get()
    --- TODO confirm that the model exists!
    assert(cm.model_is_created)
    if self._game_object then return self._game_object end
    
    return self._get_func()
end
