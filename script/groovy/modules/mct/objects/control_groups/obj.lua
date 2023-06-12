local mct = get_mct()

---@class MCT.ControlGroup : Class
local defaults = {
    ---@type string #The key of this ControlGroup.
    _key = nil,

    ---@type MCT.Mod #The Mod this ControlGroup belongs to.
    _mod = nil,

    ---@type MCT.Control[] #The Controls that are part of this ControlGroup.
    _controls = {},

    _holders = {},
}

--- TODO
--[[
    spacer / positioning systems. Should be easy to understand - control_group:add_vertical_holder() or something, which will create a vertical holder, and then you can add controls to that holder, and it'll position them vertically. Same for horizontal. This will allow for more complex layouts, like a control group with a label on the left, and a control on the right, and then a control below that, and then a control below that, etc.
        holders should probably be their own object?

    positioning for controls

    labels and icons

    mutual-exclusivity or other interactions between internal controls

    get values from controls

    
]]

---@class MCT.ControlGroup : Class #The ControlGroup class is used to group Controls together.
---@field __new fun(): MCT.ControlGroup
local ControlGroup = GLib.NewClass("MCT.ControlGroup", defaults)

function ControlGroup:new(key, mod)
    local o = self:__new()
    self.init(o, key, mod)

    return o
end

function ControlGroup:init(key, mod)
    self:set_key(key)
    self:set_mod(mod)
end

---@param parent UIC
function ControlGroup:display(parent, max_w, max_h)
    -- create the holder UIC, all labels and controls will be placed inside this.
    local holder = core:get_or_create_component(self:get_key(), "ui/campaign ui/script_dummy", parent)

    holder:SetVisible(true)

    if not is_number(max_w) then
        max_w = parent:Width()
        max_h = parent:Height()
    end

    holder:SetCanResizeHeight(true) holder:SetCanResizeWidth(true)
    holder:Resize(max_w, max_h)
    
    -- set to dock center
    holder:SetDockingPoint(5)

    -- give priority over column
    holder:PropagatePriority(parent:Priority() +1)

    -- set properties
    holder:SetProperty("mct_control_group", self:get_key())
    holder:SetProperty("mct_mod", self:get_mod():get_key())

    for i, i_holder in pairs(self._holders) do
        local dir = i_holder.direction
        local dock_point = i_holder.dock_point
        local x = i_holder.x
        local y = i_holder.y

        local template = dir == "vertical" and "ui/groovy/layouts/vlist" or "ui/groovy/layouts/hlist"

        local uic = core:get_or_create_component("holder_"..i, template, holder)
        uic:SetDockingPoint(dock_point)
        uic:SetDockOffset(x, y)

        for j, internal in pairs(i_holder.internals) do
            if is_table(internal) then
                -- internal is a holder
                -- internal:display(uic)
            else
                -- internal is a control
                internal:display(uic)
            end
        end
    end

    -- loop through all internals and display them (controls, labels, etc)
    for i = 1, #self._controls do
        local control = self._controls[i]
        control:display(holder)

        local uic = control:get_uic()
        uic:SetDockingPoint(1)
        uic:SetDockOffset(5, 10 + (i-1) * 30)
    end
end

function ControlGroup:add_holder(index, direction, dock_point, x, y)
    self._holders[#self._holders+1] = {
        index = index,
        direction = direction,
        dock_point = dock_point,
        x = x,
        y = y,

        -- either other holders or individual elements.
        internals = {},
    }
end

function ControlGroup:set_key(k)
    self._key = k
end

function ControlGroup:get_key()
    return self._key
end

function ControlGroup:set_mod(m)
    self._mod = m
end

function ControlGroup:get_mod()
    return self._mod
end

function ControlGroup:get_controls()
    return self._controls
end

---@param c MCT.Control
function ControlGroup:add_control(c)
    self._controls[#self._controls+1] = c
end

--- TODO universal functionality, labels and controls and positioning.
--- TODO move some of the existing functionality of MCT.Options into here, like how labels and info holders are currently created, and decouple "options" and "controls".


return ControlGroup