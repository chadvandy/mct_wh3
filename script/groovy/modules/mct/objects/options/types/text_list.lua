--- MCT text list type. A labelled, scrollable list of text lines, one per item, like a list of supported mods. Holds no setting.

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

-- option types load in no set order, so load the dummy directly. GLib caches it by path, so the type loader reuses this copy.
---@type MCT.Option.Dummy
local Dummy = GLib.LoadModule("dummy", GLib.ThisPath(...))

--- How many lines share one text in the list. The mouse wheel scrolls one text at a time, so this is how far each wheel click moves.
local LINES_PER_SCROLL = 3

--- Space above the first line and below the last, so they don't touch the list's border.
local LIST_PAD_Y = 6

--- Room on the right of the lines for the list's scrollbar.
local SCROLLBAR_W = 25

---@class MCT.Option.TextList
local defaults = {
    ---@type string[] The text lines shown in the list.
    _items = {},

    ---@type number How many lines are visible before the list scrolls.
    _visible_rows = 8,

    ---@type number The row layout: the list goes under the label, like radio buttons.
    _control_dock_point = 8,

}

---@class MCT.Option.TextList : MCT.Option.Dummy A scrollable list of text lines in the Settings list view. No setting is associated.
---@field __new fun():MCT.Option.TextList
local TextList = Dummy:extend("MCT.Option.TextList", defaults)

--- Replace all the lines in this list.
---@param items string[] The text lines to show, in order.
---@return boolean #False if `items` was not a table of strings.
function TextList:set_items(items)
    local valid = is_table(items)
    for _, item in ipairs(valid and items or {}) do
        if not is_string(item) then valid = false break end
    end

    if not valid then
        err("set_items() called for option ["..self:get_key().."], but the items provided were not a table of strings! Returning false.")
        return false
    end

    self._items = table.copy(items)
    self:ui_set_items()
    return true
end

--- Add one line to the end of this list. Use `set_items` to change many lines at once while the panel is open, since each call redraws the list.
---@param text string The text line to add.
---@return boolean #False if `text` was not a string.
function TextList:add_item(text)
    if not is_string(text) then
        err("add_item() called for option ["..self:get_key().."], but the text provided was not a string! Returning false.")
        return false
    end

    self._items[#self._items+1] = text
    self:ui_set_items()
    return true
end

--- Get the lines in this list.
---@return string[]
function TextList:get_items()
    return self._items
end

--- Set how many lines are visible before the list scrolls. Only read when the list is created in the UI.
---@param n number A whole number of 1 or more.
---@return boolean #False if `n` was invalid.
function TextList:set_visible_rows(n)
    if not is_number(n) or n < 1 or n % 1 ~= 0 then
        err("set_visible_rows() called for option ["..self:get_key().."], but the number provided was not a whole number of 1 or more! Returning false.")
        return false
    end

    self._visible_rows = n
    return true
end

--- Create one text in the list, holding one or more lines. It's exactly as tall as its text, so there are no gaps between texts.
---@param list_box UIC The list's box.
---@param i number The index of the text's first line, used for its id.
---@param text string The lines, joined with newlines.
---@param width number The text's width.
---@return UIC #The text.
local function create_lines(list_box, i, text, width)
    local lines = core:get_or_create_component("lines_"..i, "ui/groovy/text/fe_default", list_box)
    lines:SetCanResizeWidth(true) lines:SetCanResizeHeight(true)
    lines:Resize(width, lines:Height())
    lines:SetTextHAlign("left")
    lines:SetTextVAlign("top")
    lines:SetTextXOffset(5, 0)

    local _, text_h = lines:TextDimensionsForText(text)
    lines:Resize(width, text_h)
    lines:SetCanResizeWidth(false) lines:SetCanResizeHeight(false)
    lines:SetStateText(text)

    return lines
end

--- Show the current lines in the list, if the list exists in the UI. Lines are split into small texts of `LINES_PER_SCROLL` lines, so the
--- mouse wheel moves a few lines per click and nothing has to lay out one giant text. Each line shows on one row, so very long lines are cut off.
function TextList:ui_set_items()
    local list = self:get_uic_with_key("option")
    if not is_uicomponent(list) then return end

    local list_box = find_uicomponent(list, "list_clip", "list_box")
    list_box:DestroyChildren()

    local width = list:Width() - SCROLLBAR_W
    mct:get_ui():create_spacer(list_box, "padding_top", width, LIST_PAD_Y)

    for first = 1, #self._items, LINES_PER_SCROLL do
        local last = math.min(first + LINES_PER_SCROLL - 1, #self._items)
        create_lines(list_box, first, table.concat(self._items, "\n", first, last), width)
    end

    mct:get_ui():create_spacer(list_box, "padding_bottom", width, LIST_PAD_Y)
    list_box:Layout()
end

--- Grow the row to fit the label plus the visible lines, then fill a scrolling list with the lines.
---@param dummy_parent UIC The option row.
---@return UIC #The list view.
function TextList:ui_create_option(dummy_parent)
    -- the list spans the row's content, between its side padding
    local list_w = self:ui_get_content_width(dummy_parent)

    -- size the whole list view with its clip and scrollbar before adding lines, like the Main page description tab
    local list = core:get_or_create_component("text_list", "ui/groovy/layouts/listview", dummy_parent)
    list:SetCanResizeWidth(true) list:SetCanResizeHeight(true)
    list:Resize(list_w, dummy_parent:Height())

    -- measure a full text of lines with a throwaway text. Lines inside one text sit closer together than a lone line is tall, so this
    -- gives the real spacing, and the list shows exactly the visible rows.
    local list_box = find_uicomponent(list, "list_clip", "list_box")
    local probe = create_lines(list_box, 0, "", list_w - SCROLLBAR_W)
    local sample_lines = {}
    for i = 1, LINES_PER_SCROLL do sample_lines[i] = self._items[1] or " " end
    local sample = table.concat(sample_lines, "\n")
    local _, sample_h = probe:TextDimensionsForText(sample)
    list_box:DestroyChildren()

    local line_h = sample_h / LINES_PER_SCROLL
    local list_h = math.min(math.max(#self._items, 1), self._visible_rows) * line_h + LIST_PAD_Y * 2 + 10

    -- the box is empty again, so this only resizes the list's own parts
    list:Resize(list_w, list_h)
    list:SetCanResizeWidth(false) list:SetCanResizeHeight(false)

    self:set_uic_with_key("option", list, true)
    self:ui_set_items()

    logf("Created text list %s with %d items, %d visible", self:get_key(), #self._items, self._visible_rows)

    return list
end

return TextList
