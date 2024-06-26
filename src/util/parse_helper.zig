
const std = @import("std");
const array = @import("array.zig");



pub const DatapackErrors = error {
    EntityAlreadyExists,
    EntityDoesNotExist,
    MissingArgument,
    UnknownCommand,
    UnknownArgument,
    UnknownEntityType,
    UnknownSelectorType,
};



pub const Commands = enum {
    none,
    function,
    say,
    give,
    clear,
    summon,
    kill,
    data
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


/// This function searches and returns values from selector arguments, nbt data, and item components with the provided key.
pub fn getDataValue(nbt: []const u8, key: []const u8, value_type: enum {string, number, array, compound}) []const u8 {
    const start = if (std.mem.indexOf(u8, nbt, key)) |index| index + key.len else return "";
    var end = start + 1;
    
    switch (value_type) {
        .string => while (end < nbt.len) : (end += 1) {
            if (nbt[end] == '"' and nbt[end - 1] != '\\') break;
        },
        .number => while (end < nbt.len and nbt[end] != ',') : (end += 1) {},
        .array => while (end < nbt.len and nbt[end] != ']') : (end += 1) {},
        .compound => while (end < nbt.len and nbt[end] != '}') : (end += 1) {}
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
            .item_name = getDataValue(components, "item_name=\"", .string),
            .lore = getDataValue(components, "lore=\"", .string)
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
            .path = if (std.mem.startsWith(u8, selector, "@s")) "" else selector,
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

    fn stringToEnum(string: []const u8) !EntityType {
        return if (std.mem.eql(u8, string, "text_display")) .TextDisplay
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
        const entity_type = try EntityType.stringToEnum(entity);
        return Entity {
            .allocator = allocator,
            .entity_type = entity_type,
            .uuid = uuid_blk: {
                const uuid_str = getDataValue(nbt, "UUID:[I;", .array);
                break :uuid_blk try sanatizeUuid(allocator, uuid_str);
            },
            .nbt = switch (entity_type) {
                .TextDisplay => .{
                    .TextDisplay = .{
                        .CustomName = getDataValue(nbt, "CustomName:\"", .string),
                        .text = getDataValue(nbt, "text:\"", .string)
                    }
                }
            }
        };
    }

    pub fn deinit(self: *Entity) void {
        self.allocator.free(self.uuid);
    }
};



// TODO this struct is incomplete and has to be extended when other commands get added
pub const Selector = struct {
    selector_type: []const u8,
    arguments: ?struct {
        nbt: []const u8,
    },

    pub fn parse(selector: []const u8) Selector {
        const selector_type = if (std.mem.startsWith(u8, selector, "@")) selector[0..2] else selector[0..];

        return Selector {
            .selector_type = selector_type,
            .arguments = if (selector_type[0] != '@') null
                else .{
                    .nbt = getDataValue(selector[2..], "nbt=", .compound),
                }
        };
    }
};



/// FIX Dummy struct
pub const Coordinates = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn parse(coordinates: []const u8) Coordinates {
        _ = coordinates;
        return Coordinates{
            .x = 10,
            .y = 11,
            .z = -9
        };
    }

    pub fn overwriteData(self: *Coordinates) void {
        _ = self;
    }
};



/// FIX Dummy struct
pub const Storage = struct {
    namespace: []const u8,
    path: []const u8,

    pub fn parse(storage: []const u8) Storage {
        _ = storage;
        return Storage{
            .namespace = "_a",
            .path = "test/path"
        };
    }

    pub fn overwriteData(self: *Storage) void {
        _ = self;
    }
};



/// Allocates new memory and creates a clean and usable uuid.
pub fn sanatizeUuid(allocator: std.mem.Allocator, uuid: []const u8) ![]const u8 {
    const tmp = try array.removeScalarAlloc(u8, allocator, uuid, ' ');
    std.mem.replaceScalar(u8, tmp, ',', '_');
    defer allocator.free(tmp);

    const parts = [2][]const u8{
        "_",
        tmp
    };
    return try std.mem.concat(allocator, u8, &parts);
}



pub const DataModificationMethods = enum {
    Merge,
    Modify,
    Remove,
    Get,

    pub fn stringToEnum(string: []const u8) !DataModificationMethods {
        return if (std.mem.eql(u8, string, "modify")) .Modify
        else if (std.mem.eql(u8, string, "get")) .Get
        else if (std.mem.eql(u8, string, "merge")) .Merge
        else if (std.mem.eql(u8, string, "remove")) .Remove
        else DatapackErrors.UnknownArgument;
    }
};



pub const DataModificationTarget = enum {
    Entity,
    Block,
    Storage,

    pub fn stringToEnum(string: []const u8) !DataModificationTarget {
        return if (std.mem.eql(u8, string, "entity")) .Entity
        else if (std.mem.eql(u8, string, "block")) .Storage
        else if (std.mem.eql(u8, string, "storage")) .Block
        else DatapackErrors.UnknownArgument;
    }
};



pub const Target = union(DataModificationTarget){
    Entity: Selector,
    Block: Coordinates,
    Storage: Storage,

    pub fn parse(target_type: DataModificationTarget, target: []const u8) Target {
        return switch (target_type) {
            .Entity => Target{ .Entity = Selector.parse(target)},
            .Block => Target{ .Block = Coordinates.parse(target)},
            .Storage => Target{ .Storage = Storage.parse(target)},
        };
    }
};
