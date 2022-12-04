return {
    --- One of the default sort-section function.
    -- Sort the sections by their section key - from "!my_section" to "zzz_my_section"
    ---@param self MCT.Page.Settings
    ---@return MCT.Section[]
    key = function(self)
        local sections = self:get_assigned_sections()

        table.sort(sections, function (a, b)
            return a:get_key() < b:get_key()
        end)

        return sections
    end,

    --- One of the default sort-section functions.
    -- Sort the sections by the order in which they were added in the `mct/settings/?.lua` file.
    ---@param self MCT.Page.Settings
    ---@return MCT.Section[]
    index = function(self)
        local sections = self:get_assigned_sections()
        return sections
    end,

    ---- One of the default sort-option functions.
    --- Sort the section by their localised text - from "Awesome Options" to "Zoidberg Goes Woop Woop Woop"
    ---@param self MCT.Page.Settings
    ---@return MCT.Section[]
    localised_text = function(self)
        local sections = self:get_assigned_sections()

        table.sort(sections, function (a, b)
            return a:get_localised_text() < b:get_localised_text()
        end)

        return sections
    end
}