--- Spacing for the Settings page, in UI pixels. Every row, divider, and section header reads its spacing from here.

---@class MCT.UI.Spacing
return {
    ---@type number Space between the column edges and row content, on both sides.
    inset_x = 20,

    ---@type number Space above and below each row's content.
    row_pad_y = 12,

    ---@type number Minimum height of a row's label line. Controls are centred on this line.
    label_line_h = 16,

    ---@type number Space between the section header (or its description) and the first row.
    header_gap = 12,

    ---@type number Height of a section header.
    header_h = 34,

    ---@type number Space between the header and its description.
    desc_gap = 4,

    ---@type number Space between a label line and the icons under it.
    icons_gap = 4,

    ---@type number Height of the icons line under a label.
    icons_h = 20,

    ---@type number How far the icons start in from the label.
    icons_indent = 0,

    ---@type number Space between a label and its control on the right.
    label_gap = 16,

    ---@type number Space between stacked lines of one control, like the two bars of a range slider.
    stack_gap = 10,

    ---@type number Space between a label and a control drawn under it.
    list_gap = 6,

    ---@type number Space above and below a divider option, used instead of `row_pad_y`.
    divider_pad_y = 4,

    ---@type number Space above and below the divider between sections.
    section_gap = 16,

    ---@type number Height of the divider image.
    divider_h = 13,

    ---@type number Space at the top of each column, above the first section.
    column_pad_top = 10,

    ---@type number Space at the bottom of each column, so the last row isn't cut off by the panel frame when scrolled to the end.
    column_pad_bottom = 30,
}
