--- TODO an infobox layout - description, optional image, optional link to workshop, optional patch notes or something that can be collapsed.

local mct = get_mct()
local Super = mct._MCT_PAGE

---@class MCT.Page.Infobox
local defaults = {
    ---@type string The displayed description - required!
    description = "",

    ---@type string Link to the Steam Workshop page.
    workshop_link = "",

    ---@type string Image path to displayed image. TODO decide on the reso.
    image_path = nil,

    ---@type "top_left"|"top_right"|"top_center"
    image_position = "top_center",

    ---@type {w:number,h:number}
    image_dimensions = {w=100,h=100},
}

---@class MCT.Page.Infobox : MCT.Page, Class
---@field __new fun():MCT.Page.Infobox
local Infobox = Super:extend("Infobox", defaults)

mct:add_new_page_type("Infobox", Infobox)

function Infobox:new(key, mod, description, image_path, workshop_link)
    VLib.Log("In infobox:new()")

    local o = self:__new()
    o:init(key, mod, description, image_path, workshop_link)

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

local valid_pos = {
    top_left = true,
    top_right = true,
    top_center = true,
}

---@param pos "top_left"|"top_right"|"top_center"
function Infobox:set_image_position(pos)
    if not is_string(pos) or not valid_pos[pos] then
        -- errmsg
        return false
    end

    self.image_position = pos
end

--- TODO
function Infobox:set_image_dimensions(w, h)

end

--- draw in the UI
function Infobox:populate(box)
    local uic = core:get_or_create_component("infobox", "ui/campaign ui/script_dummy", box)
    uic:SetDockingPoint(2)
    uic:Resize(box:Width() * 0.9, box:Height())

    local xo,yo = 0,0

    if self.image_path then
        local img = core:get_or_create_component("image", "ui/vandy_lib/image", uic)
        img:SetImagePath(self.image_path)
        
        local w,h = self.image_dimensions.w, self.image_dimensions.h
        img:Resize(w, h)
        img:ResizeCurrentStateImage(0, w, h)
        local pos = self.image_position
        if pos == "top_left" then
            img:SetDockingPoint(1)

            --- TODO take into account the new dimensions
            img:SetDockOffset(0, 50)
            
        end
        
        yo = img:Height()

        if self.workshop_link then
            common.set_context_value("mct_workshop_link_"..self.mod_obj:get_key(), self.workshop_link)

            local btn = core:get_or_create_component("workshop_button", "ui/mct/workshop_button", img)

            btn:SetDockingPoint(8)
            btn:SetDockOffset(0, btn:Height() * 1.2)
            btn:SetTooltipText("Open workshop link", true)

            btn:SetContextObject(cco("CcoStringValue", self.workshop_link))
        end
    end

    if self.description then
        ---TODO set a border around it or something visually pleasing?
        local t = core:get_or_create_component("description", "ui/vandy_lib/text/dev_ui", uic)
        t:SetDockingPoint(2)
        t:SetDockOffset(0, yo + 15)
        t:Resize(400, 500)
        
        local tx,ty = t:TextDimensionsForText(self.description)
        t:Resize(tx, ty)
        t:SetStateText(self.description)
    end
end