--- TODO command systems
---@alias command_table table<string, {text:string, tooltip:string, callback:fun()}>

---@class CommandManager : Class
local defaults = {
    path = "script/vlib/mct/core/commands/",

    ---@type table<string, command_table[]>
    commands = {},
}

---@class CommandManager : Class
local CommandManager = VLib.NewClass("CommandManager", defaults)

function CommandManager:init()
    VLib.LoadModules(
        self.path,
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