--- TODO command systems
---@alias command_table table<string, {text:string, tooltip:string, callback:fun()}>

--- (...) convert the full path of this file (ie. script/folder/folders/this_file.lua) to just the path leading to specifically this file (ie. script/folder/folders/), to grab subfolders easily while still allowing me to restructure this entire mod four times a year!
local this_path = string.gsub( (...) , "[^/]+$", "")

---@class CommandManager : Class
local defaults = {

    ---@type table<string, command_table[]>
    commands = {},
}

---@class CommandManager : Class
local CommandManager = GLib.NewClass("CommandManager", defaults)

--- TODO handle the UI and call-command systems here

function CommandManager:init()
    GLib.LoadModules(
        this_path .. "commands/",
        "*.lua",
        function(filename, this_module)
            --- Assign the commands table to self.commands[filename], ie. self.commands[mct_mod] = {commands = {command_a,}} etc.

            ---= self.commands.mct_mod_commands = {command_a}
            self.commands[filename.."_commands"] = this_module

            common.set_context_value(filename.."_commands", {commands = self.commands[filename.."_commands"]})
        end
    )
end



return CommandManager