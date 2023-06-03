---@module ControlGroups

local mct = get_mct()

local Super = mct:get_control_group_class()

---@ignore
---@class Array : ControlGroup
local defaults = {
    ---@type Control[]
    _controls = {},

    _label = nil,

    _key = nil,
}

---@class Array : ControlGroup
---@field __new fun(): Array
local Array = Super:extend("Array", defaults)

function Array:new()
    local o = self:__new()
    o:init()

    return o
end

function Array:init()

    Super.init(self)
end

--- TODO
--[[
    Define the positions for each Control and assign them.
    Define if we can create new rows or if they're predetermined, and how many rows are allowed for min/max.

]]

--- Add a Control to this ControlGroup.
---@param control Control # The Control to add.
---@param pos number? The position to add the Control to. If nil, it will be added to the end.
function Array:add_control(control, pos)
    if is_nil(pos) then pos = #self._controls + 1 end

    assert(is_number(pos), "ArrayControlGroup:add_control() - pos is not a number!")
    -- assert(pos > 1 and pos <= #self._controls + 1, "ArrayControlGroup:add_control() - pos is out of bounds!")

    table.insert(self._controls, pos, control)
end

function Array:set_label_text(t)
    self._label = t
end

function Array:get_label_text()
    return self._label
end

--- Create the ArrayControlGroup in UI.
function Array:display(parent)
    -- create the holder
    local holder = core:get_or_create_component("mct_array_control_group_" .. self._key, "ui/campaign ui/script_dummy", parent)
    holder:SetDockingPoint(1)
    holder:SetDockOffset(0, 0)
    holder:Resize(parent:Width() * 0.9, 400)

    --- TODO figure out the size

    local label = core:get_or_create_component("label", "ui/groovy/text/fe_default", holder)
    label:SetStateText("Array Control Group Label")
    label:Resize(label:Width() * 2, label:Height() * 2)

    --- holder for the controls / rows / headers for each control.
    local controls_holder = core:get_or_create_component("controls_holder", "ui/campaign ui/script_dummy", holder)
    controls_holder:SetDockingPoint(3)
    controls_holder:SetDockOffset(0, 0)

    local headers = core:get_or_create_component("headers", "ui/groovy/layouts/hlist", controls_holder)
    headers:SetDockingPoint(2)
    headers:SetDockOffset(0, 0)

    --- create the headers
    for i = 1, #self._controls do
        local header = core:get_or_create_component("header_" .. i, "ui/groovy/text/fe_default", headers)
        header:SetStateText(self._controls[i]:get_text())
    end

    --- TODO create-new-row button

    local row_holder = core:get_or_create_component("row_holder", "ui/groovy/layouts/vlist", controls_holder)
    row_holder:SetDockingPoint(2)
    row_holder:SetDockOffset(0, headers:Height() + 10)

    --- create the rows
    local row = core:get_or_create_component("row_1", "ui/groovy/layouts/hlist", row_holder)

    -- create the controls
    for i = 1, #self._controls do
        local control = self._controls[i]
        local control_holder = core:get_or_create_component("control_"..control:get_key(), "ui/campaign ui/script_dummy", row)
        local uic = control:ui_create_option(control_holder)
        uic:SetDockingPoint(5)
        uic:SetDockOffset(0, 0)
    end
end

return Array