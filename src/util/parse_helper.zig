
const std = @import("std");
const array = @import("array.zig");



pub const DatapackErrors = error {
    UnknownCommand,
    MissingArgument,
    UnknownArgument,
    UnknownEntityType,
    EntityAlreadyExists
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



fn getNbtValue(nbt: []const u8, key: []const u8, value_type: enum {string, number, array}) []const u8 {
    const start = if (std.mem.indexOf(u8, nbt, key)) |index| index + key.len else return "";
    var end = start + 1;
    
    switch (value_type) {
        .string => while (end < nbt.len) : (end += 1) {
            if (nbt[end] == '"' and nbt[end - 1] != '\\') break;
        },
        .number => while (end < nbt.len and nbt[end] != ',') : (end += 1) {},
        .array => while (end < nbt.len and nbt[end] != ']') : (end += 1) {}
    }

    return nbt[start..end];
}



pub fn removeNamespaceOrReturn(id: []const u8, namespace: []const u8) []const u8 { return if (std.mem.startsWith(u8, id, namespace)) id[namespace.len + 1..] else id; }



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
            .extension = itemToExtension(removeNamespaceOrReturn(item, "minecraft")),
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



pub const EntityType = enum {
    TextDisplay,

    fn idToEnum(id: []const u8) !EntityType {
        return if (std.mem.eql(u8, id, "text_display")) .TextDisplay
            else DatapackErrors.UnknownEntityType;
    }
};

pub const Entity = struct {
    allocator: std.mem.Allocator,
    entity_type: EntityType,
    uuid: []const u8,
    nbt: union(EntityType) {
        TextDisplay: struct {
            CustomName: []const u8,
            text: []const u8,
        }
    },

    pub fn init(allocator: std.mem.Allocator, entity: []const u8, nbt: []const u8) !Entity {
        const entity_type = try EntityType.idToEnum(entity);
        return Entity {
            .allocator = allocator,
            .entity_type = entity_type,
            .uuid = uuid_blk: {
                const arr_str = getNbtValue(nbt, "UUID:[I;", .array);
                const clean_str = clean_blk: {
                    const tmp = try array.removeScalar(u8, allocator, arr_str, ' ');
                    std.mem.replaceScalar(u8, tmp, ',', '_');
                    break :clean_blk tmp;
                };
                defer allocator.free(clean_str);

                const uuid_str = str_blk: {
                    const parts = [2][]const u8{
                        "_",
                        clean_str
                    };
                    break :str_blk try std.mem.concat(allocator, u8, &parts);
                };
                break :uuid_blk uuid_str;
            },
            .nbt = switch (entity_type) {
                .TextDisplay => .{
                    .TextDisplay = .{
                        .CustomName = getNbtValue(nbt, "CustomName:\"", .string),
                        .text = getNbtValue(nbt, "text:\"", .string)
                    }
                }
            }
        };
    }

    pub fn deinit(self: *Entity) void {
        self.allocator.free(self.uuid);
    }
};


