const std = @import("std");

pub const Token = struct {
    token_type: TokenType,
    value: []const u8,
    column: usize,
    line: usize 
};

pub const TokenType = enum {
    Say,
    Tellraw,
    Selector,
    Comma,
    Colon,
    Equal,
    LBracket,
    RBracket,
    LCurly,
    RCurly,
    LParen,
    RParen,
    RangeOp,
    Space,
    LF,
    StringLiteral,
    IntLiteral,
    FloatLiteral,
    Eof,
    Error,
};

pub const LexerStatus = struct {
    yyinput: []const u8,
    yylimit: usize,
    line: usize = 1,
    token_start: usize = 0,
    yycursor: usize = 0,
    yymarker: usize = 0,
    yyctxmarker: usize = 0,

    const Self = @This();

    pub fn init(input: []const u8) @This() {
        return .{
            .yyinput = input,
            .yylimit = input.len
        };
    }

    fn getToken(self: *Self, token_type: TokenType) Token {
        return .{
            .token_type = token_type,
            .column = self.yycursor,
            .line = self.line,
            .value = self.yyinput[self.token_start..self.yycursor],
        };
    }
};

pub fn lex(yyrecord: *LexerStatus) !Token {
    if (yyrecord.yycursor >= yyrecord.yylimit) {
        return yyrecord.getToken(.Eof);
    }

    yyrecord.token_start = yyrecord.yycursor;

    /*!re2c
        re2c:api = record;
        re2c:yyfill:enable = 0;
        
        string_literal = "\""[^"]*"\"";
        int_literal = "-"?[0-9]+;
        float_literal = "-"?(![0-9]*"."[0-9]+|[0-9]+"."[0-9]*);

        "#".* {
            yystate = 0;
            continue :yyl;
        }

        "say" { return yyrecord.getToken(.Say); }

        "tellraw" { return yyrecord.getToken(.Tellraw); }

        "@"[spnae] { return yyrecord.getToken(.Selector); }

        ":" { return yyrecord.getToken(.Colon); }

        "," { return yyrecord.getToken(.Comma); }

        "=" { return yyrecord.getToken(.Equal); }

        ".." { return yyrecord.getToken(.RangeOp); }

        " " { return yyrecord.getToken(.Space); } 

        string_literal { return yyrecord.getToken(.StringLiteral); }

        float_literal { return yyrecord.getToken(.FloatLiteral); }
        int_literal { return yyrecord.getToken(.IntLiteral); }

        "\r\n" | "\n\r" | "\n" {
            yyrecord.line += 1;
            var token = yyrecord.getToken(.LF);
            token.value = "\\n";
            return token;
        }

        * { return yyrecord.getToken(.Error); }
    */
}
