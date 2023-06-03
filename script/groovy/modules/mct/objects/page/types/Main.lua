---@module Page

--- Main Page for an MCT Mod.
-- Includes a description, primary image, author[s], version, patch notes, and the ability to customize for the modder in question.

local MCT = get_mct()
local Super = MCT:get_mct_page_class()

---@ignore
---@class Main : Page, Class
local defaults = {
    ---@type string #The type of page this is.
    _type = "main",

    ---@type string #The title of this page.
    _title = "Main",

    ---@type string #The description of this page.
    _description = "Main Page for an MCT Mod. Includes a description, primary image, author[s], version, patch notes, and the ability to customize for the modder in question.",


    ---@type table<string, {button:UIComponent, populate:fun(UIComponent)}> #The tabs for this page.
    _tabs = {},

    ---@type {button:UIComponent, populate:fun(UIComponent)} #The currently selected tab.
    _selected_tab = nil,
}

---@class Main : Page
local Main = Super:extend("MCT.Page.Main", defaults)

--- Constructor for the Main Page.
---@param mod mct_mod The mod this page is for.
function Main:new(mod)
    local o = self:__new()
    o:init(mod)

    return o
end

--- Initialize the Main Page.
---@param mod mct_mod The mod this page is for.
function Main:init(mod)
    Super.init(self, "main", mod)

    -- self._title = mod:get_title()
    -- self._description = mod:get_description()
end

--- Populate the Main Page.
---@param panel UIC The panel to populate.
function Main:populate(panel)
    local mod = self._mod_obj

    -- left sidebar which sits statically on the screen. This is where the mod's title, description, author, version, and patch notes will be.
    local sidebar = core:get_or_create_component("sidebar", "ui/groovy/image", panel)
    sidebar:Resize(panel:Width() * 0.4 - 10, panel:Height() - 10)
    sidebar:SetDockingPoint(4)
    sidebar:SetDockOffset(5, -5)
    sidebar:SetImagePath("ui/skins/default/panel_stack_flush.png")
    sidebar:SetCurrentStateImageTiled(0, true)
    sidebar:SetCurrentStateImageMargins(0, 12, 12, 12, 12)

    self._sidebar = sidebar

    -- right panel, which sits with a scrollbar. This side will have a tabbed interface for the modder to customize.
    local main_view = core:get_or_create_component("main_view", "ui/groovy/image", panel)
    main_view:Resize(panel:Width() * 0.6 - 10, panel:Height()- 10)
    main_view:SetDockingPoint(6)
    main_view:SetDockOffset(-5, -5)
    main_view:SetImagePath("ui/skins/default/parchment_divider_flush.png")

    self._main_view = main_view

    self._tabs = {}
    self._selected_tab = nil

    self:populate_sidebar()
    self:populate_main_view()
end

function Main:populate_sidebar()
    local mod = self._mod_obj
    local sidebar = self._sidebar

    --- TODO is there any border needed? (yes)
    -- mod image
    local mod_image = core:get_or_create_component("mod_image", "ui/groovy/image", sidebar)
    mod_image:Resize(sidebar:Width() * 0.6, sidebar:Width() * 0.6)
    mod_image:SetDockingPoint(2)
    mod_image:SetDockOffset(0, 10)
    local img = mod:get_main_image()
    mod_image:SetImagePath(img)

    local buttons_holder = core:get_or_create_component("buttons_holder", "ui/groovy/layouts/hlist", sidebar)
    buttons_holder:Resize(sidebar:Width() * 0.9, 30)
    buttons_holder:SetDockingPoint(2)
    buttons_holder:SetDockOffset(0, mod_image:Height() + 20)

    -- add any buttons to the button holder that the modder has defined
    do
        local function create_link_button(key, tooltip, link)
            local link_button = core:get_or_create_component("button_"..key, "ui/groovy/buttons/icon_button", buttons_holder)
            link_button:SetImagePath("ui/mct/icons/"..key..".png")
            link_button:SetTooltipText(tooltip, true)
            link_button:Resize(32, 32)

            local function open()
                -- OpenOverlayToUrl(path, true|false)
                common.set_context_value("CcoScriptObject", "Mct"..key:gsub("^%l", string.upper).."Link", link)
                common.call_context_command("CcoScriptObject", "Mct"..key:gsub("^%l", string.upper).."Link", "OpenOverlayToUrl(StringValue, false)")
            end

            local addr = link_button:Address()

            core:add_listener(
                key.."_button_clicked",
                "ComponentLClickUp",
                function(context)
                    return context.component == addr
                end,
                function()
                    open()
                end,
                true
            )
        end

        local workshop_link = mod:get_workshop_link()
        local github_link = mod:get_github_link()

        if workshop_link ~= "" then
            create_link_button("workshop", "Steam Workshop||Open the Steam Workshop Page in the in-game browser.", workshop_link)
        end

        if github_link ~= "" then
            create_link_button("github", "GitHub||Open the GitHub Page in the in-game browser.", github_link)
        end
    end

    local details_list = core:get_or_create_component("details_holder", "ui/groovy/layouts/vlist", sidebar)
    details_list:Resize(sidebar:Width() * 0.9, sidebar:Height() - mod_image:Height() - 20)
    details_list:SetDockingPoint(2)
    details_list:SetDockOffset(0, mod_image:Height() + buttons_holder:Height() + 30)

    local function create_header(row, key, text)
        local txt_uic = core:get_or_create_component(key .. "_header", "ui/groovy/text/fe_bold", row)
        txt_uic:Resize(row:Width() * 0.4, row:Height())
        txt_uic:SetDockingPoint(4)
        txt_uic:SetDockOffset(0, 0)
        txt_uic:SetStateText(text)
        txt_uic:SetTextXOffset(5, 0)
        txt_uic:SetTextYOffset(0, 0)
        txt_uic:SetTextVAlign("centre")
    end

    local function create_text(row, key, text)
        local txt_uic = core:get_or_create_component(key .. "_text", "ui/groovy/text/fe_default", row)
        txt_uic:Resize(row:Width() * 0.6, row:Height())
        txt_uic:SetDockingPoint(6)
        txt_uic:SetDockOffset(0, 0)
        txt_uic:SetStateText(text)
        txt_uic:SetTextXOffset(5, 0)
        txt_uic:SetTextYOffset(0, 0)
        txt_uic:SetTextVAlign("centre")
    end

    local function create_row(key, header, text)
        local row = core:get_or_create_component(key .. "_row", "ui/campaign ui/script_dummy", details_list)
        row:Resize(sidebar:Width() * 0.9, 30)

        create_header(row, key, header)
        create_text(row, key, text)
    end

    local author, version = mod:get_author(), mod:get_version()

    if author ~= "" then
        create_row("author", "Created by: ", author)
    end

    if version ~= "" then
        create_row("version", "Current Version: ", version)
    end
end

function Main:populate_main_view()
    local mod_obj = self:get_mod()
    local main_view = self._main_view

    local tabs = core:get_or_create_component("tabs", "ui/groovy/layouts/hlistview", main_view)
    tabs:Resize(main_view:Width() - 4, 50)
    tabs:SetDockingPoint(1)
    tabs:SetDockOffset(2, 10)
    tabs:SetCurrentStateImageOpacity(0, 0)

    local box = find_uicomponent(tabs, "list_clip", "list_box")

    local tab_view = core:get_or_create_component("tab_view", "ui/campaign ui/script_dummy", main_view)
    tab_view:Resize(main_view:Width(), main_view:Height() - tabs:Height() - 20)
    tab_view:SetDockingPoint(2)
    tab_view:SetDockOffset(0, tabs:Height() + 20)

    self._tab_view = tab_view
    self._tab_holder = box

   -- If the mod obj has a description, add a description tab.
    if mod_obj:get_description() ~= "" then
        self:add_tab(
            "description", 
            "Description", 
            "View the mod's description.",
            function(uic)
                local list = core:get_or_create_component("list_view", "ui/groovy/layouts/listview", uic)
                list:Resize(uic:Width(), uic:Height())
                list:SetDockingPoint(2)

                local list_box = find_uicomponent(list, "list_clip", "list_box")
                local txt = core:get_or_create_component("description_text", "ui/groovy/text/fe_default", list_box)

                txt:Resize(uic:Width() - 10, uic:Height() - 10)

                txt:SetDockingPoint(2)
                txt:SetTextXOffset(5, 5)
                txt:SetTextYOffset(5, 5)
                txt:SetStateText(mod_obj:get_description())
                txt:SetTextVAlign("top")

                local tw, th = txt:TextDimensions()
                txt:Resize(tw, th)
            end
        )
    end

    -- If the mod obj has a changelog, add a changelog tab.
    -- if mod_obj:get_changelog() ~= "" then
    --     create_tab("changelog", "Changelog", "View the mod's changelog.")
    -- end

    --- Credits tab

    -- Add all modder-defined tabs from mod obj.
    for key, tab in pairs(mod_obj:get_main_page_tabs()) do
        self:add_tab(key, tab.title, tab.tooltip, tab.populate_function)
    end
end

--- Add a tab to the tab_holder, and also save the details of that tab, including the population function.
function Main:add_tab(key, title, tooltip, populate)
    local box = self._tab_holder
    local tab_path = "ui/templates/square_medium_text_tab"

    local tab = core:get_or_create_component("tab_"..key, tab_path, box)
    -- tab:Resize(tabs:Width() * 0.2, tabs:Height())
    tab:SetDockingPoint(4)
    tab:SetDockOffset(0, 0)
    -- tab:SetStateText(text)
    tab:SetTooltipText(tooltip, true)

    local tx = find_uicomponent(tab, "tx")
    tx:SetStateText(title)

    local addr = tab:Address()

    core:add_listener(
        key.."_tab_clicked",
        "ComponentLClickUp",
        function(context)
            return context.component == addr
        end,
        function()
            self:switch_tab(key)
        end,
        true
    )

    self._tabs[key] = {
        button = tab,
        populate = populate
    }

    if not self._selected_tab then
        self:switch_tab(key)
    end
end

-- Populate main view with selected tab.
function Main:switch_tab(key)
    local tab = self._tabs[key]
    local last_selected = self._selected_tab

    if last_selected then
        last_selected.button:SetState("active")
    end

    self._tab_view:DestroyChildren()

    if tab then
        tab.populate(self._tab_view)
        tab.button:SetState("selected")
        self._selected_tab = tab
    end
end


return Main
