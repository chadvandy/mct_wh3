--- MCT image type. A picture on its own row, with a choice of size and alignment. Holds no setting.
--- The image must ship inside a mod pack, like `ui/my_mod/banner.png`. Text does not wrap around it.

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

-- option types load in no set order, so load the dummy directly. GLib caches it by path, so the type loader reuses this copy.
---@type MCT.Option.Dummy
local Dummy = GLib.LoadModule("dummy", GLib.ThisPath(...))

--- The dock point inside the row for each alignment.
local ALIGNMENT_DOCKS = {left = 4, centre = 5, right = 6}

---@class MCT.Option.Image
local defaults = {
    ---@type string The image path inside a pack. Set with `image_set_path`.
    _path = "",

    ---@type number? The width to draw the image at. Uses the image's own width when not set.
    _width = nil,

    ---@type number? The height to draw the image at. Uses the image's own height when not set.
    _height = nil,

    ---@type "left"|"centre"|"right" Where the image sits in the row. Set with `image_set_alignment`.
    _alignment = "centre",

    ---@type number The row layout: full width with no label, so the row fits the image.
    _control_dock_point = 5,
}

---@class MCT.Option.Image : MCT.Option.Dummy A picture in the Settings list view. No setting is associated.
---@field __new fun():MCT.Option.Image
local Image = Dummy:extend("MCT.Option.Image", defaults)

--- Set the image to show. The path is inside a pack, like `ui/my_mod/banner.png`.
---@param path string
---@return MCT.Option.Image|false
function Image:image_set_path(path)
    if not is_string(path) or path == "" then
        err("image_set_path() called for option ["..self:get_key().."], but the path supplied is not a non-empty string! Returning false.")
        return false
    end

    self._path = path
    return self
end

--- Get the image path.
---@return string
function Image:image_get_path()
    return self._path
end

--- Set the size to draw the image at, instead of its own size. An image wider than the row still shrinks to fit, keeping its shape.
---@param width number
---@param height number
---@return MCT.Option.Image|false
function Image:image_set_size(width, height)
    if not is_number(width) or not is_number(height) or width <= 0 or height <= 0 then
        err("image_set_size() called for option ["..self:get_key().."], but the width and height must be numbers above 0! Returning false.")
        return false
    end

    self._width = width
    self._height = height
    return self
end

--- Get the size set with `image_set_size`, or nil for the image's own size.
---@return number?, number?
function Image:image_get_size()
    return self._width, self._height
end

--- Set where the image sits in the row. Only read when the image is created in the UI.
---@param alignment "left"|"centre"|"center"|"right"
---@return MCT.Option.Image|false
function Image:image_set_alignment(alignment)
    local name = self:check_alignment(alignment, "image_set_alignment")
    if not name then return false end

    self._alignment = name
    return self
end

--- Get where the image sits in the row.
---@return "left"|"centre"|"right"
function Image:image_get_alignment()
    return self._alignment
end

--- Work out the size to draw the image at, shrunk to fit `max_w` while keeping its shape.
---@param natural_w number The image's own width.
---@param natural_h number The image's own height.
---@param max_w number The widest the image can be.
---@return number, number
function Image:ui_get_draw_size(natural_w, natural_h, max_w)
    local w, h = self._width or natural_w, self._height or natural_h
    if w > max_w then
        h = h * max_w / w
        w = max_w
    end

    return math.floor(w), math.floor(h)
end

--- Create the image in a holder across the row's content. A missing image leaves an empty row and logs an error.
---@param dummy_parent UIC The option row.
---@return UIC #The holder for the image.
function Image:ui_create_option(dummy_parent)
    local width = self:ui_get_content_width(dummy_parent)

    local holder = core:get_or_create_component("mct_image_holder", "ui/campaign ui/script_dummy", dummy_parent)
    holder:SetInteractive(false)

    local img_w, img_h = 0, 0
    if self._path == "" then
        err("Image option ["..self:get_key().."] has no image path. Set one with image_set_path().")
    else
        local img = core:get_or_create_component("mct_image", "ui/groovy/image", holder)
        img:SetImagePath(self._path, 0, true)

        local natural_w, natural_h = img:GetImageDimensions(0)
        if not natural_w or natural_w <= 0 or natural_h <= 0 then
            err("Image option ["..self:get_key().."] could not load the image ["..self._path.."]. Is it in a pack?")
            img:SetVisible(false)
        else
            -- the game sets the path twice, or the image can lose its shape. Its resize flag resets the size, so this goes before sizing.
            img:SetImagePath(self._path, 0, true)

            img_w, img_h = self:ui_get_draw_size(natural_w, natural_h, width)
            img:SetCanResizeWidth(true) img:SetCanResizeHeight(true)
            img:Resize(img_w, img_h)
            img:ResizeCurrentStateImage(0, img_w, img_h)
            img:SetCanResizeWidth(false) img:SetCanResizeHeight(false)
            img:SetDockingPoint(ALIGNMENT_DOCKS[self._alignment])
            img:SetDockOffset(0, 0)

            local tt = self:get_tooltip_text()
            img:SetInteractive(tt ~= "")
            if tt ~= "" then img:SetTooltipText(tt, true) end
        end
    end

    holder:Resize(width, img_h)

    self:set_uic_with_key("option", holder, true)
    return holder
end

return Image
