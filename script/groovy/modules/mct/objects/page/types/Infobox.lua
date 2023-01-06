--- TODO an infobox layout - description, optional image, optional link to workshop, optional patch notes or something that can be collapsed.

local mct = get_mct()
local Super = mct:get_mct_page()

---@class MCT.Page.Infobox
local defaults = {}

---@class MCT.Page.Infobox : MCT.Page, Class
---@field __new fun():MCT.Page.Infobox
local Infobox = Super:extend("Infobox", defaults)

function Infobox:new(key, mod)
    GLib.Log("In infobox:new()")

    local o = self:__new()
    o:init(key, mod)

    return o
end

--- TODO methods for editing all of that.
--- TODO pass forward all the necessary params (description, image, workshop link, etc.)
function Infobox:init(key, mod)
    GLib.Log("In infobox:init()")
    Super.init(self, key, mod)
end

--- TODO author[s]
--- TODO workshop link
--- TODO quick description
--- TODO version

--- TODO do it more like an Infobox, layout engine + vlist + holders per row
--- TODO versions and changelog button for popup w/ each changelog
--- draw in the UI
function Infobox:populate(box)
    --- infobox_holder is needed because list_box automatically reorders and spaces its children; this way, we can control spacing far better.
    -- local infobox_holder = core:get_or_create_component("infobox_holder", "ui/campaign ui/script_dummy", box)
    -- infobox_holder:Resize(box:Width(), box:Height())

    --- TODO listview without scrollbar, center of screen
    local uic = core:get_or_create_component("infobox", "ui/groovy/image", box)
    uic:SetDockingPoint(2)
    uic:SetDockOffset(0, 10)
    uic:Resize(box:Width() * 0.4, box:Height() * 0.94)
    uic:SetImagePath("ui/skins/default/avatar_frame_custom_battle.png")

    local mod = self._mod_obj

    local xo,yo = 0,0

    local p,w, h = mod:get_main_image()
    --- TODO border around image
    if p then
        local img = core:get_or_create_component("image", "ui/groovy/image", uic)
        img:SetImagePath(p)

        img:Resize(w, h)
        img:ResizeCurrentStateImage(0, w, h)
        img:SetDockingPoint(2)

        --- TODO take into account the new dimensions
        img:SetDockOffset(0, 10)
        yo = yo + img:Height() + 10

        if mod:get_workshop_link() ~= "" then
            --- TODO set the img
            common.set_context_value("mct_workshop_link_"..mod:get_key(), mod:get_workshop_link())

            local btn = core:get_or_create_component("workshop_button", "ui/mct/workshop_button", img)

            btn:SetDockingPoint(8)
            btn:SetDockOffset(0, btn:Height() * 1.2)
            btn:SetTooltipText("Open Steam Workshop page", true)

            --- this don't work
            btn:SetContextObject(cco("CcoStringValue", mod:get_workshop_link()))

            yo = yo + btn:Height() * 1.4
        end
    end

    local d = mod:get_description()
    if d then
        ---TODO set a border around it or something visually pleasing?
        local t = core:get_or_create_component("description", "ui/vandy_lib/text/paragraph", uic)
        t:SetDockingPoint(2)
        t:SetDockOffset(0, yo + 15)
        t:Resize(uic:Width() * 0.95, 40)
        t:SetCanResizeWidth(false)

        local tx,ty = t:TextDimensionsForText(d)
        t:Resize(tx, ty)
        t:SetStateText(d)
    end
end

return Infobox