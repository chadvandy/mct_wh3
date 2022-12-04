--- TODO a visual layout within MCT, so you can do stuff like "3 equal columns" or "a double-wide column on the left and an image on the right" or whatever, inserting spots for options or text or wiki or whatever you want
--- TODO this should be an object which holds sections or different data in it, ie. a "description" layout might have description text, optional patch note / author / workshop link details, optional image, etc.
--- TODO every Layout is a Page - the main landing page, specific settings in different pages, wiki, patch notes, etc. Aside from the Main layout, each will have their own subheader displayed under the mod header when clicked.

---@class MCT.Page : Class
local defaults = {
    ---@type string #The Key identifier for this page.
    key = "",

    ---@type UIComponent #The row header for this Page.
    row_uic = nil,

    ---@type MCT.Mod #The MCT.Mod this page belongs to.
    mod_obj = nil,
}

---@class MCT.Page : Class
---@field __new fun():MCT.Page
local Page = GLib.NewClass("Layout", defaults)

---@param mod MCT.Mod
---@return MCT.Page
function Page:new(key, mod)
    local o = self:__new()
    ---@cast o MCT.Page
    o:init(key, mod)

    return o
end


function Page:init(key, mod)
    self.key = key
    self.mod_obj = mod
end

---@param uic UIC
function Page:set_row_uic(uic)
    if is_uicomponent(uic) then
        self.row_uic = uic
    end
end

function Page:get_row_uic()
    return self.row_uic
end

function Page:get_key()
    return self.key
end

--- TODO Create the UI panel for this layout.
function Page:populate(panel)

end

--- Called on UIC creation.
function Page:create_row_uic()
    local left_panel = get_mct().ui.mod_row_list_box
    local list_view = get_mct().ui.mod_row_list_view
    local mod_obj = self.mod_obj
    local page_key = self.key

    local page_row = core:get_or_create_component(mod_obj:get_key().."_"..page_key, "ui/vandy_lib/row_header", left_panel)
    page_row:SetVisible(true)
    page_row:SetCanResizeHeight(true) page_row:SetCanResizeWidth(true)
    page_row:Resize(list_view:Width() * 0.8, page_row:Height() * 0.95)
    page_row:SetDockingPoint(2)
    page_row:SetProperty("mct_mod", mod_obj:get_key())
    page_row:SetProperty("mct_layout", page_key)
    local diff = list_view:Width() * 0.95 - page_row:Width()
    page_row:SetDockOffset(diff - 5, 0)

    --- This hides the +/- button from the row headers.
    for i = 0, page_row:NumStates() -1 do
        page_row:SetState(page_row:GetStateByIndex(i))
        page_row:SetCurrentStateImageOpacity(1, 0)
    end
    
    page_row:SetState("active")

    local txt = find_uicomponent(page_row, "dy_title")

    txt:Resize(page_row:Width() * 0.9, page_row:Height() * 0.9)
    txt:SetDockingPoint(2)
    txt:SetDockOffset(10,0)

    _SetStateText(txt, page_key)

    -- local tt = mod_obj:get_tooltip_text()

    -- if is_string(tt) and tt ~= "" then
    --     page_row:SetTooltipText(tt, true)
    -- end
    -- page_row:SetVisible(false)

    self:set_row_uic(page_row)

    --- TODO do this? Or just hold it in the Page?
    mod_obj:set_page_uic(page_row)
end

return Page