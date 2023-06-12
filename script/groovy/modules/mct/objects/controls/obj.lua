--- TODO a specific class for the Control type; this should just be the individual Control UI components and how they handle values and such.

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct_control]")

---@class MCT.Control : Class
local defaults = {
    ---@type MCT.Mod # The Mod this Control belongs to.
    _mod = nil,
    ---@type string # The key for this Control.
    _key = "",
    ---@type string # The text for this Control.
    _type = nil,

    ---@type UIC #The Control's UIComponent.
    uic = nil,

    ---@type boolean # Whether or not this Control is global.
    _is_global = false,

    ---@type any # The default value for this Control.
    _default_value = nil,
    ---@type any # The globally-saved value for this Control. This is basically a user-assigned default.
    _global_value = nil,
    ---@type any # The current value for this Control.
    _loaded_value = nil,
    ---@type any # The currently selected, but unsaved, value for this Control.
    _selected_value = nil,

    ---@type boolean # Whether or not this Control is locked.
    _is_locked = false,
    ---@type string # The reason for this Control being locked.
    _lock_reason = "",

    ---@type boolean # Whether or not this Control is hidden.
    _is_hidden = false,
}

---@class MCT.Control : Class
---@field __new fun(): MCT.Control
local Control = GLib.NewClass("MCT.Control", defaults)

function Control:new()
    -- this is a dummy class which should never be called.
    -- it's just here to make sure that all Controls have the same functions.
    error("MCT.Control:new() - This is a dummy class and should never be called!")
end

function Control:init(mod_obj, key)
    self._mod = mod_obj
    self._key = key
end

function Control:display(parent)

end

function Control:set_uic(uic)
    self.uic = uic
end

function Control:get_uic()
    return self.uic
end

function Control:get_mod()
    return self._mod
end

function Control:get_key()
    return self._key
end

function Control:get_type()
    return self._type
end

function Control:is_global()
    return self._is_global
end

function Control:is_locked()
    return self._is_locked
end

function Control:is_hidden()
    return self._is_hidden
end

function Control:lock(reason)
    self._is_locked = true
    self._lock_reason = reason
end

function Control:unlock()
    self._is_locked = false
    self._lock_reason = ""
end

function Control:hide()
    self._is_hidden = true
end

function Control:show()
    self._is_hidden = false
end

function Control:default()
    return self._default_value
end

function Control:global()
    return self._global_value
end

function Control:loaded()
    return self._loaded_value
end

function Control:selected()
    return self._selected_value
end

-- TODO a clear way to get the current value based on context, globality, selectedness, etc.
function Control:current()
    return self:selected()
end

function Control:check_validity(value)

end

function Control:set_global_value(value)
    local is_valid, new_val = self:check_validity(value)

    if not is_valid then
        errf("set_global_value() called for mct_option [%s] in mct_mod [%s], but the value passed is not valid! Value passed: [%s], new value: [%s]", self:get_key(), self:get_mod():get_key(), tostring(value), tostring(new_val))
        value = new_val
    end

    self._global_value = value
end

function Control:set_default_value(value)
    local is_valid, new_val = self:check_validity(value)

    if not is_valid then
        errf("set_default_value() called for mct_option [%s] in mct_mod [%s], but the value passed is not valid! Value passed: [%s], new value: [%s]", self:get_key(), self:get_mod():get_key(), tostring(value), tostring(new_val))
        value = new_val
    end

    self._default_value = value
end

return Control