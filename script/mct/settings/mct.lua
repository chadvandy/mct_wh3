local mct = get_mct()

local mct_mod = mct:register_mod("mct_mod")
mct_mod:set_workshop_id("2927955021")
mct_mod:set_version(mct:get_version_number(), mct:get_version())
mct_mod:set_main_image("ui/mct/van_mct.png", 300, 300)
mct_mod:set_description("The Mod Configuration Tool, home of all things mod and configuration!")

local mct_logging = mct_mod:add_new_option("lib_logging", "checkbox")
mct_logging:set_default_value(true)

mct_logging:set_text("Logging: Groove Library")
mct_logging:set_tooltip_text("Allows the Groove Library (MCT and all submods) to print a log file to your desktop. It's very performative and refreshes every time the game is loaded.")
mct_logging:set_is_global(true)

local game_logging = mct_mod:add_new_option("game_logging", 'checkbox')
game_logging:set_default_value(false)

game_logging:set_text("Logging: Base Game")
game_logging:set_tooltip_text("Allows the base game to print a log file to the game's directory. [[col:red]]Base game logging can slow down the game, and is recommended for debugging and crashes only.[[/col]]")
game_logging:set_is_global(true)
