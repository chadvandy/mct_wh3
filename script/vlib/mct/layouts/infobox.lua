--- TODO an infobox layout - description, optional image, optional link to workshop, optional patch notes or something that can be collapsed.

local mct = get_mct()
local Super = mct._MCT_PAGE

---@class MCT.Page.Infobox : MCT.Page
local defaults = {
    ---@type string The displayed description - required!
    description = "",

    ---@type string Link to the Steam Workshop page.
    workshop_link = "",

    ---@type string Image path to displayed image. TODO decide on the reso.
    image_path = nil,
}

---@class MCT.Page.Infobox : MCT.Page
local Infobox = Super:extend("Infobox", defaults)

mct:add_new_page_type("Infobox", Infobox)

function Infobox:new(key, mod, description, image_path, workshop_link)
    VLib.Log("In infobox:new()")
    local o = self:__new()
    ---@cast o MCT.Page.Infobox
    o:init(key, mod, description, workshop_link, image_path)

    return o
end

--- TODO methods for editing all of that.
--- TODO pass forward all the necessary params (description, image, workshop link, etc.)
function Infobox:init(key, mod, description, image_path, workshop_link)
    VLib.Log("In infobox:init()")
    Super.init(self, key, mod)

    self.description = description
    self.workshop_link = workshop_link
    self.image_path = image_path
end

--- TODO draw in the UI
function Infobox:create()
    local uic = get_mct().ui.mod_settings_panel

    local xo,yo = 0,0
    if self.image_path then
        local img = core:get_or_create_component("image", "ui/vandy_lib/image", uic)
        img:SetImagePath(self.image_path)
        img:SetDockingPoint(2)
        img:SetDockOffset(0, 50)
        img:SetVisible(true) -- TODO needed?
        
        yo = img:Height()
    end

    if self.description then
        local t = core:get_or_create_component("description", "ui/vandy_lib/text/dev_ui", uic)
        t:SetStateText(self.description)
        t:SetDockingPoint(2)
        t:SetDockOffset(0, yo + 15)
    end
end