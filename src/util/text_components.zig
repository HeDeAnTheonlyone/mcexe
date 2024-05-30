
// const std = @import("std");



// const PlainTextObject = struct {
//     text: []const u8,
// };

// const TranslatedTextObject = struct {
//     translate: []const u8,
//     fallback: []const u8,
//     with: []TextComponent
// };

// const ScoreValueObject = struct {
//     score: Score
// };

// const Score = struct {
//     name: []const u8,
//     objective: []const u8,
//     value: []const u8
// };

// const EntityNameObject = struct {
//     selector = []const u8,
//     seperator = TextComponent
// };

// const KeybindObject = struct {
//     keybind = enum {
//         key_advancements,
//         key_attack,
//         key_back,
//         key_chat,
//         key_command,
//         key_drop,
//         key_forward,
//         key_fullscreen,
//         key_hotbar1,
//         key_hotbar2,
//         key_hotbar3,
//         key_hotbar4,
//         key_hotbar5,
//         key_hotbar6,
//         key_hotbar7,
//         key_hotbar8,
//         key_hotbar9,
//         key_inventory,
//         key_jump,
//         key_left,
//         key_load_toolbar_activator,
//         key_pick_item,
//         key_player_list,
//         // ... There are more I have to add later
//     },
// };

// const NbtValueObject = struct {
//     nbt: []const u8,
//     block: []const u8,
//     entity: []const u8,
//     storage : []const u8
// };

// const ObjectType = union(enum) {
//     plain_text: PlainTextObject,
//     translated_text: TranslatedTextObject,
//     score_value: ScoreValueObject,
//     entity_name: EntityNameObject,
//     keybind: KeybindObject,
//     nbt_value: NbtValueObject
// };

// const Object = struct {
//     obj_type: ObjectType,
//     color: []const u8,
//     bold: bool = false,
//     italic: bool = false,
//     underlined: bool = false,
//     strikethrough: bool = false,
//     // obfuriscated: bool = false,
//     // insertion: []const u8,    // Maye instead of inserting text to the chat, make it copy to clipboard.
//     // click_event: .{} = .{},
//     // hover_event: .{} = .{},
//     // extra: @This() = .{}
// };

// const TextComponent = struct {
//     obj: Object,
//     array: []Object,
//     string: []const u8
// };