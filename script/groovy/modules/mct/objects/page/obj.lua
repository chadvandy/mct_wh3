---@class MCT.Page : Class
local defaults = {
    ---@type string #The Key identifier for this page.
    _key = "",

    ---@type UIComponent #The row header for this Page.
    _row_uic = nil,

    ---@type MCT.Mod #The MCT.Mod this page belongs to.
    _mod_obj = nil,

    ---@type boolean #Whether or not this page is visible.
    _visibility = true,
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
    -- assert(get_mct():verify_key(self, key))
    self._key = key
    self._mod_obj = mod
end

---@param uic UIC
function Page:set_row_uic(uic)
    if is_uicomponent(uic) then
        self._row_uic = uic
    end
end

function Page:get_row_uic()
    return self._row_uic
end

function Page:get_key()
    return self._key
end

function Page:get_mod()
    return self._mod_obj
end

---@param uic UIComponent
---@abstracted
function Page:OnPopulate(uic)

end

--- Create the UI panel for this layout. (Overridden by subclasses)
function Page:populate(panel)
end

---@param bool boolean
function Page:set_visibility(bool)
    assert(is_boolean(bool), "set_visibility() must be passed a boolean!")
    self._visibility = bool

    if self:get_row_uic() then
        self:get_row_uic():SetVisible(bool)
    end
end

---@return boolean
function Page:get_visibility()
    return self._visibility
end

--- Called on UIC creation.
function Page:create_row_uic()
    local left_panel = get_mct():get_ui().mod_row_list_box
    local list_view = get_mct():get_ui().mod_row_list_view
    local mod_obj = self._mod_obj
    local page_key = self._key

    if not list_view then return end

    local page_row = core:get_or_create_component(mod_obj:get_key().."_"..page_key, "ui/vandy_lib/row_header", left_panel)
    
    page_row:SetVisible(mod_obj.__bRowsOpen)
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
    txt:SetDockingPoint(4)
    txt:SetDockOffset(0,0)

    txt:SetStateText(page_key)
    txt:SetTextXOffset(10, 15)
    txt:SetTextVAlign("centre")
    txt:SetTextHAlign("left")

    -- local tt = mod_obj:get_tooltip_text()

    -- if is_string(tt) and tt ~= "" then
    --     page_row:SetTooltipText(tt, true)
    -- end
    -- page_row:SetVisible(false)

    self:set_row_uic(page_row)
end

return Page