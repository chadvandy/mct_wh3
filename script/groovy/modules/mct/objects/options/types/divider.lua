--- MCT divider type. A thin horizontal line between options, for grouping them inside a section. Holds no setting.

local mct = get_mct()

-- option types load in no set order, so load the dummy directly. GLib caches it by path, so the type loader reuses this copy.
---@type MCT.Option.Dummy
local Dummy = GLib.LoadModule("dummy", GLib.ThisPath(...))

---@class MCT.Option.Divider
local defaults = {
    ---@type number The row layout: full width with no label, so the row is just the line and its padding.
    _control_dock_point = 5,
}

---@class MCT.Option.Divider : MCT.Option.Dummy A thin line that takes up a short spot in the Settings list view. No setting is associated.
---@field __new fun():MCT.Option.Divider
local Divider = Dummy:extend("MCT.Option.Divider", defaults)

--- Dividers sit closer to their neighbours than rows do.
---@return number
function Divider:ui_get_padding_y()
    return mct:get_ui():get_spacing().divider_pad_y
end

--- Draw the divider line across the row's content. The row's height is set by `ui_layout_row`.
---@param dummy_parent UIC The option row.
---@return UIC #The divider image.
function Divider:ui_create_option(dummy_parent)
    local div = mct:get_ui():create_divider_image(dummy_parent, self:ui_get_content_width(dummy_parent))

    self:set_uic_with_key("option", div, true)
    return div
end

return Divider
