--- A "Fake Example Mod" page in MCT's own mod. It lays out a made-up mod's settings with every element together, as a model for mod authors.
--- This file loads right after mct.lua, which registers MCT's own mod.

local mct = get_mct()
local mct_mod = mct:get_mod_by_key("mct_mod")

--- Add a section to a page.
---@param page MCT.Page.Settings The page to add it to.
---@param key string The section's key.
---@param title string The section's title.
---@param column number? The column to pin the section to. Unpinned sections fill the columns in order.
---@return MCT.Section
local function add_section(page, key, title, column)
    local section = mct_mod:add_new_section(key, title)
    section:assign_to_page(page)
    if column then section:set_column(column) end
    return section
end

--- Add a text block.
---@param key string The option's key.
---@param text string The text, which can use colour tags.
---@param style "body"|"bold"|"italic"|"faded"|"subheading"|"heading"
---@param alignment "left"|"centre"|"right"
local function add_text(key, text, style, alignment)
    local option = mct_mod:add_new_option(key, "text")
    option:set_text(text)
    option:text_set_style(style)
    option:text_set_alignment(alignment)
end

--- Add an image.
---@param key string The option's key.
---@param path string The image path inside a pack.
---@param alignment "left"|"centre"|"right"
---@param tooltip string? The text shown when hovering the image.
---@return MCT.Option.Image
local function add_image(key, path, alignment, tooltip)
    local option = mct_mod:add_new_option(key, "image")
    option:image_set_path(path)
    option:image_set_alignment(alignment)
    if tooltip then option:set_tooltip_text(tooltip) end
    return option
end

local example_page = mct_mod:create_settings_page("Fake Example Mod", 2)

-- Column 1
add_section(example_page, "example_intro", "Imperial Roads Overhaul", 1)

add_image("example_banner", "ui/loading_ui/load_images/campaign_empire1.png", "centre")
add_text("example_title", "Roads, Tolls, and Trouble", "heading", "centre")
add_text("example_intro_text", "Imperial Roads Overhaul turns the roads of the Empire into something worth fighting over. "
    .. "Each paved road earns [[col:yellow]]+50 gold[[/col]] a turn and gives armies on it [[col:green]]+20% movement[[/col]], "
    .. "but bandits and beastmen will try to cut them.", "body", "left")
add_text("example_author", "by Example Author - version 1.2", "faded", "centre")

add_section(example_page, "example_gameplay", "Gameplay", 1)

local difficulty = mct_mod:add_new_option("example_difficulty", "dropdown")
difficulty:set_text("Bandit difficulty")
difficulty:set_tooltip_text("How hard bandit raids are to fight off.")
difficulty:add_dropdown_value("easy", "Easy", "Small raids that a garrison can handle.", false)
difficulty:add_dropdown_value("normal", "Normal", "Raids that need an army to clear.", true)
difficulty:add_dropdown_value("hard", "Hard", "Raids that can cut a province off.", false)

local tolls = mct_mod:add_new_option("example_tolls", "checkbox")
tolls:set_text("Collect road tolls")
tolls:set_tooltip_text("Roads earn gold each turn while no enemy army stands on them.")
tolls:set_default_value(true)

-- a long label wraps onto more lines beside its control, and the row grows to fit it
local foreign_tolls = mct_mod:add_new_option("example_foreign_tolls", "checkbox")
foreign_tolls:set_text("Also collect tolls on roads that pass through provinces you do not own yet, at half the usual rate")
foreign_tolls:set_default_value(false)

local toll_rate = mct_mod:add_new_option("example_toll_rate", "slider")
toll_rate:set_text("Toll rate (%)")
toll_rate:set_tooltip_text("The share of trade income that roads earn.")
toll_rate:slider_set_style("bar")
toll_rate:slider_set_min_max(0, 100)
toll_rate:slider_set_step_size(5, 0)
toll_rate:set_default_value(25)

mct_mod:add_new_option("example_gameplay_divider", "divider")

local event_turns = mct_mod:add_new_option("example_event_turns", "range_slider")
event_turns:set_text("Road events between turns")
event_turns:set_tooltip_text("Road events can only fire between these two turns.")
event_turns:slider_set_min_max(0, 200)
event_turns:slider_set_step_size(5, 0)
event_turns:set_default_value({10, 150})

local road_name = mct_mod:add_new_option("example_road_name", "text_input")
road_name:set_text("Name of the first road")
road_name:set_default_value("Old Dwarf Road")
road_name:add_validity_test(function(value)
    if value == "" then return false, "The road needs a name." end
    return true
end)

-- Column 2
add_section(example_page, "example_events", "Events", 2)

add_image("example_event_picture", "ui/eventpics/emp/celebration.png", "centre")
add_text("example_events_text", "When a road is finished, its province holds a feast. Turn these events off if you would rather keep the gold.", "body", "left")

local feasts = mct_mod:add_new_option("example_feasts", "checkbox")
feasts:set_text("Road feasts")
feasts:set_default_value(true)

local ambushes = mct_mod:add_new_option("example_ambushes", "checkbox")
ambushes:set_text("Bandit ambushes")
ambushes:set_default_value(true)

local max_events = mct_mod:add_new_option("example_max_events", "slider")
max_events:set_text("Most events per turn")
max_events:slider_set_min_max(1, 5)
max_events:set_default_value(2)

local compatibility = add_section(example_page, "example_compatibility", "Compatibility", 2)
compatibility:set_is_collapsible(true)

add_text("example_compatibility_heading", "Works with", "subheading", "left")

local supported = mct_mod:add_new_option("example_supported_mods", "text_list")
supported:set_text("Supported mods (30)")
local mods = {}
for i = 1, 30 do mods[i] = "Example Supported Mod " .. i end
supported:set_items(mods)
supported:set_visible_rows(6)

add_text("example_compatibility_note", "Mods that change the campaign map should load before this one.", "italic", "left")

add_section(example_page, "example_credits", "Credits", 2)

add_image("example_credits_flag", "ui/flags/wh_main_emp_empire/mon_64.png", "left")
add_text("example_credits_thanks", "Thanks to", "bold", "left")
add_text("example_credits_names", "The road crews of Altdorf, every tester who got ambushed, and you for reading this far.", "body", "left")
