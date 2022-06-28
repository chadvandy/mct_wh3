--- TODO an infobox layout - description, optional image, optional link to workshop, optional patch notes or something that can be collapsed.

local mct = get_mct()
local Super = mct._LAYOUT

local defaults = {
    ---@type string The displayed description - required!
    description = "",

    ---@type string Link to the Steam Workshop page.
    workshop_link = "",

    ---@type string Image path to displayed image. TODO decide on the reso.
    image_path = nil,
}

---@class MCT.Layout.Infobox : MCT.Layout
local Infobox = Super:extend("Infobox", defaults)

mct:add_new_layout("Infobox", Infobox)

function Infobox:new()
    local o = self:__new()
    o:init()

    return o
end

--- TODO methods for editing all of that.
--- TODO pass forward all the necessary params (description, image, workshop link, etc.)
function Infobox:init()
    Super.init(self)
end

--- TODO create in the UI
function Infobox:create()

end