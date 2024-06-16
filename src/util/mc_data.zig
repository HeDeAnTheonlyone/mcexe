
const std = @import("std");



pub const datapackErrors = error {
    UnknownCommand,
    MissingArguments
};



pub const Commands = enum {
    none,
    function,
    say,
    give,
    clear,
    summon,
};



pub fn getPrimaryCmd(command: []const u8) ?[]const u8 {
    const first_char = std.mem.indexOfNone(u8, command, " ") orelse return null;

    if (std.mem.startsWith(u8, command[first_char..], "#"))
        return null;
    
    if (std.mem.startsWith(u8, command[first_char..], "\n"))
        return null;
    
    var i: usize = 0;
    return getNextArgument(command[first_char..], &i, ' ');
}



/// Returns the next argument in the command from the given starting index or null if there is no next argument. It also increases the given index value to the next arguments start index.
pub fn getNextArgument(command: []const u8, start_index: *usize, delimiter: u8) ?[]const u8 {
    const start: usize = start_index.*;

    if (start >= command.len) return null;

    const end = std.mem.indexOfScalarPos(u8, command, start, delimiter) orelse command.len;

    start_index.* = end + 1;
    return command[start..end];
}



fn getNbtValue(components: []const u8, component_key: []const u8, value_type: enum {string, number}) []const u8 {
    const start_index = if (std.mem.indexOf(u8, components, component_key)) |index| index + component_key.len else return "";
    var end_index = start_index + 1;
    
    if (value_type == .string) {
        while (true) : (end_index += 1) {
            if (components[end_index] == '"' and !(components[end_index - 1] == '\\')) break;
        }
    }
    else {
        while (end_index < components.len and components[end_index] != ',') : (end_index += 1) {}
    }
    return components[start_index..end_index];
}



const ItemComponents = struct {
    item_name: []const u8,
    lore: []const u8,

    // FIX you can easily confuse and potentially break it if you use the the needle in your text

    fn parse(components: []const u8) ItemComponents {
        return ItemComponents {
            .item_name = getNbtValue(components, "item_name=\"", .string),
            .lore = getNbtValue(components, "lore=\"", .string)
        };
    }
};



pub const FileInfo = struct {
    path: []const u8,
    name: []const u8,
    extension: []const u8,
    data: []const u8,

    pub fn parse(context: []const u8) FileInfo {
        var context_index: usize = 0;

        const selector = getNextArgument(context, &context_index, ' ').?;
        const item = getNextArgument(context, &context_index, '[').?;
        const item_component = component_blk: {
            const components_string = getNextArgument(context, &context_index, ']').?;
            const components = ItemComponents.parse(components_string);

            break :component_blk ItemComponents{
                .item_name = components.item_name,
                .lore = components.lore
            };
        };

        //TODO currently only supports selectors that are names and plain @s
        return FileInfo {
            .path = if (std.mem.startsWith(u8, selector, "@")) "" else selector,
            .extension = if (std.mem.startsWith(u8, item, "minecraft:")) itemToExtension(item[10..]) else itemToExtension(item),
            .name = item_component.item_name,
            .data = item_component.lore
        };
    }

    fn itemToExtension(item: []const u8) []const u8 {
        return if (std.mem.eql(u8, item, "*")) ""
            else if (std.mem.eql(u8, item, "paper")) ".txt"
            else ".txt";
    }
};







