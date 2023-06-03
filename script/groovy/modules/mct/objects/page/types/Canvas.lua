---@module Page

--- a do-anything-to-it canvas page

local mct = get_mct()
local Super = mct:get_mct_page_class()

---@ignore
---@class Canvas
local defaults = {
    creation_callback = function(canvas) end,
}

---@class Canvas : Page, Class
---@field __new fun():Canvas
local Canvas = Super:extend("Canvas", defaults)

function Canvas:new(key, mod, creation_callback)
    GLib.Log("In Canvas:new()")

    local o = self:__new()
    o:init(key, mod, creation_callback)

    return o
end

function Canvas:init(key, mod, creation_callback)
    GLib.Log("In Canvas:init()")
    Super.init(self, key, mod)

    self:set_creation_callback(creation_callback)
end

--- Set the creation callback for the Canvas; it will be a function that takes in the Canvas UIC, and is run whenever the Canvas page is opened up.
---@param fn fun(canvas:UIC)
function Canvas:set_creation_callback(fn)
    if not is_function(fn) then
        return
    end

    self.creation_callback = fn
end

function Canvas:populate(box)
    -- --- Canvas_holder is needed because list_box automatically reorders and spaces its children; this way, we can control spacing far better.
    -- local canvas = core:get_or_create_component("canvas_holder", "ui/campaign ui/script_dummy", box)
    -- canvas:Resize(box:Width(), box:Height())

    self.creation_callback(box)
end

return Canvas
