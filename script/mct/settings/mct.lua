local mct = get_mct()

local mct_mod = mct:register_mod("mct_mod")
mct_mod:set_workshop_link("https://steamcommunity.com/sharedfiles/filedetails/?id=2815354316")
mct_mod:set_version(mct:get_version())
mct_mod:set_main_image("ui/mct/van_mct.png", 300, 300)
mct_mod:set_description("The Mod Configuration Tool, home of all things mod and configuration!")

mct_mod:use_infobox(true)

-- mct_mod:create_infobox_page("Details", "My Description", "ui/mct/van_mct.png")


-- mct_mod:set_tooltip_text("Testing this tooltip text out!")

-- local section = mct_mod:add_new_section("my_section", "This Is My Section")
-- section:set_tooltip_text("My Section||This section is all about cool stuff.")

-- mct_mod:create_patch("v2.6.98.12-a078\nJuly 17th, 2021", [[
--     This is a relatively small patch to incorporate a few more fixes and some new functionality.

--     New Stuff!
--     - Section headers can now have tooltip texts for when they're hovered upon.

--     Changes for Modders!
--     - Localisation has changed fundamentally. There will be continued support for the old method, but now you can provide multiple loc-keys to any localised text. Instead of using `mct_mod:set_title("loc_key", true)`, you can now use `mct_mod:set_title("{{loc:loc_key}}:{{loc:loc_key_for_more_text}}")`. It'll add in more flexibility with how you use localised keys, hopefully!
--     - I changed how the text_input_add_validity_test() function operates, as well. Now the function takes in the supplied text, but it'll return first true/false for if it was valid, and then the error message if invalid. Ie.:
--         text_input_add_validity_test(function(text) 
--             if text == "Bloop" then return false, "Bloop is not accepted!" end
--             return true
--         end

--     - As always, backwards compatibility for both of the above remains - but change over to the newer system as early as you can!
--     - Added `mct_section:set_tooltip_text("text")` and `mct_section:get_tooltip_text()`. As with other localisation, it defaults to searching for a localisation key at `mct_[section_key]_section_tooltip_text`. NOTE: This IS NOT backwards compatible because it's new!

--     Bug Squashed!
--     - The settings rows no longer grow wildly large as you scroll down a big mod. Oopsie!
--     - Tabs on mods will be set invisible if they're not valid for that mod - no logging button without logs, no patch notes button without patch notes.
--     - Fixed a small bug with mod description text.
--     - Visually added in the section names within the Finalize Settings popup, fixed the spacing a bit, and added in tooltips so it's more readable.
--     - Change patch notes text to left-aligned, just reads better.

--     Known Issues
--     - Left-aligned text on the patch notes (here) looks kinda weird if you try to indent. Gotta fix gotta fix.
--     ]],
--     2,
--     false
-- )

-- mct_mod:create_patch("Brass Bull & Blowpipe\nJuly 14th, 2021", [[
--     New Feature!
--     - Added in this Patch Notes functionality that you're reading this note on.
--     - Added in backend support to expand similar functionality via tabs or external UI.
--     - Beginning iteration of the "VLib", for Vandy Library - a collection of shared functions I have written up that can make a lot of stuff easier for modders (hopefully!)
    
--     Changes for Modders!
--     - Overwrote the CA Script Launcher - the path `./pack/script/mod/` will now load all .lua files within, *after* everything else. This is for scripts that aren't necessarily libraries, but are available in every game mod.
--         - I also fix up ModLog(), so it doesn't break whenever a non-string is passed to it, and it now has multiple-arg support - so you can use ModLog("My", "Message"), and both will print.
--     - Added in `mct_mod:create_patch(name, description, position, is_important)`. Docs may have to wait a bit to update, with the changed backend.
--         - Name is the big name, description is the body, position is where it goes compared to other patches (lower number is lower on the list), is_important determines whether a popup should be triggered. Use sparingly!
--     - Easy to add MCT functionality, if you wanted. Any file in `.pack/script/vlib/modules/mod_configuration_tool/modules/` will be loaded within the MCT body, and you can overwrite anything I add in. I'll be moving as much of the mod into separate modules, so it's easier to digest piecemeal and add new stuff.
--     - Increased support for new tabs and arbitrarily run UI. You can now tell the UI to open up whenever, and open up to any mod page and any tab, and it'll respond accordingly (see mct/modules/patch_notes for an example). You can also create new tabs - but for right now, they're available on all mods. That'll be changed in the future!

--     Bug Fixes!
--     - The Profiles dropdown will now properly display the currently selected Profile, every time you open up the panel.
--     - Small other bug fixes.

--     Known Issues!
--     - If there's more than one popup at a time, ie. two mods with a new Patch, and you press "Yes" to view the first one, the second popup will immediately be triggered, annoyingly. This is going to be resolved next patch.

--     Most importantly, this patch comes with a big backend update that has allowed me to conglomerate a large amount of my mods into one single .pack. This .pack file currently contains a load of stuff, a lot of it in the early or middle stages of development. I'll be taking the next few chunks of time to start grinding out some of these features, more news on that in the future.
--     ]],
--     1,
--     true
-- )

--- TODO new section for specifically logging!
local logging = mct_mod:add_new_option("enable_logging", "checkbox")
--test:set_default_value(false)
logging:set_locked(true, "[[col:red]]This option is currently broken as heck![[/col]]")
logging:set_text("[DISABLED]") -- Logging: Vanilla/Mods
logging:set_tooltip_text("This option doesn't do anything right now, I have to fix it. :)")
logging:set_local_only(true)
logging:set_is_global(true)

local mct_logging = mct_mod:add_new_option("mct_logging", "checkbox")
mct_logging:set_default_value(true)

mct_logging:set_text("Logging: Vandy Library")
mct_logging:set_tooltip_text("Allows the Vandy Library (MCT and all submods) to print a log file to your desktop. It's very performative and refreshes every time the game is loaded.")
mct_logging:set_local_only(true)