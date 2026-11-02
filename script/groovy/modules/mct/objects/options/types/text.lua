--- MCT text type. A block of text across the whole row, with a choice of style and alignment. Holds no setting.
--- Set the text with `set_text`. The game's colour tags work in every style, like `[[col:yellow]]Gold[[/col]]`.

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

-- option types load in no set order, so load the dummy directly. GLib caches it by path, so the type loader reuses this copy.
---@type MCT.Option.Dummy
local Dummy = GLib.LoadModule("dummy", GLib.ThisPath(...))

--- The text template for each style.
local STYLE_TEMPLATES = {
    body = "ui/groovy/text/fe_default",
    bold = "ui/groovy/text/fe_bold",
    italic = "ui/groovy/text/fe_italic",
    faded = "ui/groovy/text/fe_faded",
    subheading = "ui/groovy/text/paragraph_header",
    heading = "ui/groovy/text/section_header",
}

---@class MCT.Option.Text
local defaults = {
    ---@type "body"|"bold"|"italic"|"faded"|"subheading"|"heading" How the text is drawn. Set with `text_set_style`.
    _style = "body",

    ---@type "left"|"centre"|"right" Where the text sits in the row. Set with `text_set_alignment`.
    _alignment = "left",

    ---@type number The row layout: full width with no label, so the row fits the text.
    _control_dock_point = 5,
}

---@class MCT.Option.Text : MCT.Option.Dummy A block of text in the Settings list view. No setting is associated.
---@field __new fun():MCT.Option.Text
local Text = Dummy:extend("MCT.Option.Text", defaults)

--- Set how the text is drawn. Only read when the text is created in the UI.
---@param style "body"|"bold"|"italic"|"faded"|"subheading"|"heading"
---@return MCT.Option.Text|false
function Text:text_set_style(style)
    if not STYLE_TEMPLATES[style] then
        err("text_set_style() called for option ["..self:get_key().."], but the style ["..tostring(style).."] is not body, bold, italic, faded, subheading, or heading! Returning false.")
        return false
    end

    self._style = style
    return self
end

--- Get how the text is drawn.
---@return "body"|"bold"|"italic"|"faded"|"subheading"|"heading"
function Text:text_get_style()
    return self._style
end

--- Set where the text sits in the row. Only read when the text is created in the UI.
---@param alignment "left"|"centre"|"center"|"right"
---@return MCT.Option.Text|false
function Text:text_set_alignment(alignment)
    local name = self:check_alignment(alignment, "text_set_alignment")
    if not name then return false end

    self._alignment = name
    return self
end

--- Get where the text sits in the row.
---@return "left"|"centre"|"right"
function Text:text_get_alignment()
    return self._alignment
end

--- Create the text across the row's content, wrapping long text. The row's height is set by `ui_layout_row`.
---@param dummy_parent UIC The option row.
---@return UIC #The text.
function Text:ui_create_option(dummy_parent)
    local text = self:get_text()
    local width = self:ui_get_content_width(dummy_parent)

    local text_uic = core:get_or_create_component("mct_text", STYLE_TEMPLATES[self._style], dummy_parent)
    text_uic:SetCanResizeWidth(true) text_uic:SetCanResizeHeight(true)
    text_uic:Resize(width, text_uic:Height())
    text_uic:SetTextHAlign(self._alignment)
    text_uic:SetTextVAlign("top")
    text_uic:SetTextXOffset(0, 0)
    text_uic:SetTextYOffset(0, 0)

    -- measured at the final width, so wrapped lines are counted
    local _, text_h = text_uic:TextDimensionsForText(text)
    text_uic:Resize(width, text_h)
    text_uic:SetCanResizeWidth(false) text_uic:SetCanResizeHeight(false)
    text_uic:SetStateText(text)
    text_uic:SetInteractive(false)

    self:set_uic_with_key("option", text_uic, true)
    return text_uic
end

return Text
