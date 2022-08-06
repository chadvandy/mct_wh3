--- TODO special Dropdown type that used Game Objects instead of predefined strings.

--- TODO saved setting should be the DB key


---@type MCT.Option.Dropdown
local Super = get_mct()._MCT_TYPES.dropdown

local mct = get_mct()
local log,logf,err,errf = get_vlog("[mct]")

---@class MCT.Option.SpecialDropdown : MCT.Option.Dropdown
local defaults = {
    database_record = "CcoFactionRecord", --- The Cco Class we're looking for.
    filtered_list = {"wh3_main_cth_cathay_mp", "wh3_main_ksl_kislev", "wh3_main_ogr_ogre_kingdoms"}, -- The filtered acceptable CcoClasses. This can be defined using :set_filtered_list() and supplying the Database keys for the desired objects, or you can set a filter function.
}

---@class MCT.Option.SpecialDropdown : MCT.Option.Dropdown
---@field __new fun():MCT.Option.SpecialDropdown
local SpecialDropdown = Super:extend("SpecialDropdown", defaults)

function SpecialDropdown:new(mod_obj, option_key)
    local o = self:__new()
    o:init(mod_obj, option_key)

    return o
end

function SpecialDropdown:init(mod_obj, option_key)
    --- anything?
    Super.init(self, mod_obj, option_key)
end

--- TODO set the record type we're looking for.
---@param db string 
function SpecialDropdown:set_database_record(db)
    if not is_string(db) then
        --- errmsg!
        return false
    end

    --- TODO make sure it's a valid database record type!

    self.database_record = db
end

--- Set the Filtered List for individual dropdown records that are valid for this dropdown. 
---@param t string[] A table of strings, which should be the relevant DB keys for the record in question.
function SpecialDropdown:set_filtered_list(t)
    self.filtered_list = t
end

--- TODO load and create the CcoContext needed.
function SpecialDropdown:refresh_context()
    --- TODO save the filtered list contexts as a CcoContextList on the option UIC!
    local list = self.filtered_list
    

end

--- TODO set the display of each Dropdown row based on the context pulled from the database record (ie. dropdown.text = Context.Name for CcoFactionRecord)
function SpecialDropdown:set_display_for_context()

end

function SpecialDropdown:refresh_dropdown_box()
    local uic = self:get_uic_with_key("option")

    local popup_menu = UIComponent(uic:Find("popup_menu"))
    local popup_list = UIComponent(popup_menu:Find("popup_list"))

    -- clear out any extant chil'uns
    popup_list:DestroyChildren()

    local selected_tx = UIComponent(uic:Find("dy_selected_txt"))
    
    -- local selected_value = self:get_selected_setting()

    --- TODO should we make a dropdown_option template for each and every supported DatabaseRecord and define their appearance through there? Just use SetContextObject and then read and supply through the layout file?
    --- TODO we want to loop through the Filtered List, get the CcoContext for that record, and apply the UI to it (and also save that CcoContext to that dropdown row)
    -- local dropdown_values = self:get_values()

    local values = self.filtered_list

    local dropdown_option_template = "ui/vandy_lib/dropdown_option"

    for i,context_key in ipairs(values) do

        local new_entry = core:get_or_create_component(context_key, dropdown_option_template, popup_list)
        new_entry:SetProperty("mct_option", self:get_key())
        new_entry:SetProperty("mct_mod", self:get_mod_key())
        new_entry:SetContextObject(cco(self.database_record, context_key))
        
        -- -- if they're localised text strings, localise them!
        -- do
        --     local test_tt = common.get_localised_string(tt)
        --     if test_tt ~= "" then
        --         tt = test_tt
        --     end

        --     local test_text = common.get_localised_string(text)
        --     if test_text ~= "" then
        --         text = test_text
        --     end
        -- end

        -- new_entry:SetTooltipText(tt, true)

        local off_y = 5 + (new_entry:Height() * (i-1))

        new_entry:SetDockingPoint(2)
        new_entry:SetDockOffset(0, off_y)

        w,h = new_entry:Dimensions()

        local txt = find_uicomponent(new_entry, "row_tx")

        --- TODO let this work for things other than CcoFactionRecord
        local text = common.get_context_value(self.database_record, context_key, "NameWithIcon")
        txt:SetStateText(text)

        if i == 1 then selected_tx:SetStateText(text) end

        -- -- check if this is the default value
        -- if selected_value == key then
        --     new_entry:SetState("selected")

        --     -- add the value's tt to the actual dropdown box
        --     selected_tx:SetStateText(text)
        --     uic:SetTooltipText(tt, true)
        -- end

        new_entry:SetCanResizeHeight(false)
        new_entry:SetCanResizeWidth(false)
    end


    local border_top = find_uicomponent(popup_menu, "border_top")
    local border_bottom = find_uicomponent(popup_menu, "border_bottom")
    
    border_top:SetCanResizeHeight(true)
    border_top:SetCanResizeWidth(true)
    border_bottom:SetCanResizeHeight(true)
    border_bottom:SetCanResizeWidth(true)

    popup_list:SetCanResizeHeight(true)
    popup_list:SetCanResizeWidth(true)
    popup_list:Resize(w * 1.1, h * (#values) + 10)
    --popup_list:MoveTo(popup_menu:Position())
    popup_list:SetDockingPoint(2)
    --popup_list:SetDocKOffset()

    popup_menu:SetCanResizeHeight(true)
    popup_menu:SetCanResizeWidth(true)
    popup_list:SetCanResizeHeight(false)
    popup_list:SetCanResizeWidth(false)
    
    local w, h = popup_list:Bounds()
    popup_menu:Resize(w,h)
end

--- TODO 
function SpecialDropdown:ui_create_option(dummy_parent)
    local box = "ui/vandy_lib/dropdown_button"

    local new_uic = core:get_or_create_component("mct_dropdown_game_object_box", box, dummy_parent)
    new_uic:SetVisible(true)
    new_uic:Resize(dummy_parent:Width() * 0.4, new_uic:Height())

    local popup_menu = find_uicomponent(new_uic, "popup_menu")
    popup_menu:PropagatePriority(1000) -- higher z-value than other shits
    popup_menu:SetVisible(false)
    --popup_menu:SetInteractive(true)

    local popup_list = find_uicomponent(popup_menu, "popup_list")
    popup_list:PropagatePriority(popup_menu:Priority()+1)
    --popup_list:SetInteractive(true)

    self:set_uic_with_key("option", new_uic, true)

    self:refresh_dropdown_box()

    return new_uic
end


--- TODO shouldn't the sub listener be inside of this listener?
core:add_listener(
    "mct_dropdown_box",
    "ComponentLClickUp",
    function(context)
        return context.string == "mct_dropdown_game_object_box"
    end,
    function(context)
        local box = UIComponent(context.component)
        local menu = find_uicomponent(box, "popup_menu")

        local mod_obj = mct:get_selected_mod()
        local option_key = box:GetProperty("mct_option")
        local option_obj = mod_obj:get_option_by_key(option_key)

        if is_uicomponent(menu) then
            if menu:Visible(false) then
                menu:SetVisible(false)
            else
                menu:SetVisible(true)
                menu:RegisterTopMost()
                -- next time you click something, close the menu!
                core:add_listener(
                    "mct_dropdown_box_close",
                    "ComponentLClickUp",
                    true,
                    function(context)
                        core:remove_listener("mct_dropdown_box_option_selected")
                        if box:CurrentState() == "selected" then
                            box:SetState("active")
                        end

                        menu:SetVisible(false)
                        menu:RemoveTopMost()
                    end,
                    false
                )

                -- Set Selected listeners
                core:add_listener(
                    "mct_dropdown_box_option_selected",
                    "ComponentLClickUp",
                    function(context)
                        local uic = UIComponent(context.component)
                        
                        return UIComponent(uic:Parent()):Id() == "popup_list" and uicomponent_descended_from(uic, "mct_dropdown_game_object_box")
                    end,
                    function(context)
                        -- core:remove_listener("mct_dropdown_box_close")
                        log("mct_dropdown_box_option_selected")
                        local uic = UIComponent(context.component)

                        -- this operation is set externally (so we can perform the same operation outside of here)
                        local ok, msg = pcall(function()
                        option_obj:set_selected_setting(uic:Id())
                        end) if not ok then err(msg) end
                    end,
                    false
                )
            end
        end
    end,
    true
)


return SpecialDropdown