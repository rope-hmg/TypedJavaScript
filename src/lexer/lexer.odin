package lexer

import "core:strconv"

// -----------------------------------------------------------------------------
// Lexer

@private
Mode :: union {
    Normal,
    Identifier,
    Number,
    String,
    Operator,
}

// Need a better name for this
@private
Result :: enum {
    Processed,
    Unprocessed,
}

@private
Lex_State :: struct {
    source:   string,
    mode:     Mode,
    result:   Result,
    index:    int,
    location: Location
}

lex_source :: proc(source: string) {
    lex_state := Lex_State {
        source = source,
        mode   = Normal {},
    }

    next_location := Location {
        line   = 1,
        column = 0,
    }

    processed: for c, i in source {
        lex_state.location = next_location
        lex_state.index    = i
        
        next_location.column += 1

        if c == '\n' {
            next_location.column = 1
            next_location.line  += 1
        }

        unprocessed: for {
            lex_state.result = Result.Processed

            switch mode in &lex_state.mode {
                case Normal:     lex_normal    (c, &lex_state, &mode)
                case Identifier: lex_identifier(c, &lex_state, &mode)
                case Number:     lex_number    (c, &lex_state, &mode)
                case String:     lex_string    (c, &lex_state, &mode)
                case Operator:   lex_operator  (c, &lex_state, &mode)
            }

            switch lex_state.result {
                case .Processed:   continue processed
                case .Unprocessed: continue unprocessed
            }
        }
    }
}

// -----------------------------------------------------------------------------
// Normal

@private
Normal :: struct {}

@private
set_normal_mode :: proc(state: ^Lex_State) {
    state.mode = Normal {}
}

@private
lex_normal :: proc(
    c:      rune,
    state:  ^Lex_State,
    mode:   ^Normal,
) {
    switch {
        case is_white_space(c):
            // Skip white space characters

        case is_identifier_start(c):
            set_identifier_mode(state)

        case is_numeric_start(c):
            set_number_mode(state, c)

        case is_string_delimiter(c):
            set_string_mode(state, c)

        case:
            set_operator_mode(state)
            state.result = .Unprocessed
    }
}

@private
is_white_space :: #force_inline proc(c: rune) -> bool {
    return c <= ' '
}

// -----------------------------------------------------------------------------
// Identifier

@private
Identifier :: struct {
    first_index: int,
}

@private
set_identifier_mode :: proc(state: ^Lex_State) {
    state.mode = Identifier {
        first_index = state.index,
    }
}

@private
lex_identifier :: proc(
          c:     rune,
          state: ^Lex_State,
    using mode:  ^Identifier,
) {
    if !is_identifier_continue(c) {
        lexeme := state.source[mode.first_index:state.index]
        found  := false

        kind:  Token_Kind
        value: Token_Value

        for i := 0;
            i < len(IDENTIFIERS) && !found;
            i += 1
        {
            identifier := IDENTIFIERS[i]

            found = identifier.lexeme == lexeme
            kind  = identifier.kind
            value = identifier.value
        }

        // This should stop anyone moving the last entry in IDENTIFIERS array.
        if !found do assert(kind == .Identifier)

        token := Token {
            kind     = kind,
            value    = value,
            location = state.location,
            span     = Span { first_index, state.index }, 
        }

        set_normal_mode(state)
        state.result = .Unprocessed
    }
}

is_identifier_start :: #force_inline proc(c: rune) -> bool {
    return c >= 'a' && c <= 'z' ||
           c >= 'A' && c <= 'Z'
}

is_identifier_continue :: #force_inline proc(c: rune) -> bool {
    return is_identifier_start(c) ||
           is_numeric_start(c)    ||
           c == '_'               ||
           c == '$'
}

@private
Identifier_Map_Entry :: struct {
    lexeme: string,
    kind:   Token_Kind,
    value:  Token_Value,
}

@private
Identifier_Map :: []Identifier_Map_Entry

@private
IDENTIFIERS := Identifier_Map {
    { "import", .Import,    nil   },
    { "export", .Export,    nil   },
    { "if",     .If,        nil   },
    { "else",   .Else,      nil   },
    { "for",    .For,       nil   },
    { "while",  .While,     nil   },
    { "type",   .Type,      nil   },
    { "object", .Object,    nil   },
    { "union",  .Union,     nil   },
    { "enum",   .Enum,      nil   },
    { "fn",     .Fn,        nil   },
    { "self",   .Self,      nil   },
    { "Self",   .Self_Type, nil   },
    { "true",   .Boolean,   true  },
    { "false",  .Boolean,   false },

    // IMPORTANT: This must be the last entry in the map.
    { "", .Identifier, nil },
}

// -----------------------------------------------------------------------------
// Number

@private
Number :: struct {
    first_index:         int,
    integer_base:        int,
    needs_clarification: bool,
    is_float:            bool,
    is_numeric_continue: proc(rune) -> bool,
}

@private
set_number_mode :: proc(state: ^Lex_State, c: rune) {
    state.mode = Number {
        first_index         = state.index,
        needs_clarification = c == '0',
    }
}

@private
lex_number :: proc(
          c:     rune,
          state: ^Lex_State,
    using mode:  ^Number,
) {
    if  needs_clarification {
        needs_clarification = false

        switch c {
            case 'b': {
                is_numeric_continue = is_binary_continue
                integer_base        = 2
            }

            case 'o': {
                is_numeric_continue = is_octal_continue
                integer_base        = 8
            }

            case 'x': {
                is_numeric_continue = is_hexadecimal_continue
                integer_base        = 16
            }

            case: {
                is_numeric_continue = is_decimal_continue
                integer_base        = 10

            }
        }

        if is_numeric_continue != is_decimal_continue {
            // We don't include the prefix in the lexeme.
            first_index = state.index + 1
        }
    } else {
        if c == '.' {
            if is_float {
                // TODO: Error
            }

            is_float = true
        }

        if !is_numeric_continue(c) {
            kind: Token_Kind

            if c == 'n' {
                if is_float {
                    // TODO: Error
                }

                kind = .Big_Integer
            } else if is_float {
                kind = .Float
            } else {
                kind = .Integer
            }

            lexeme := state.source[mode.first_index:state.index]

            value: Token_Value
            ok:    bool

            #partial switch kind {
                case .Integer:      value, ok = strconv.parse_i64(lexeme, integer_base)
                case .Float:        value, ok = strconv.parse_f64(lexeme)
                case .Big_Integer:  value, ok = 0, true // TODO: Support big integers
            }

            if !ok {
                // TODO: Error
            }

            token := Token {
                kind     = kind,
                value    = value,
                location = state.location,
                span     = Span { first_index, state.index }, 
            }

            set_normal_mode(state)
            state.result = .Unprocessed
        }
    }
}

@private
is_numeric_start :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '9'
}

@private
is_binary_continue :: #force_inline proc(c: rune) -> bool {
    return c == '0' || c == '1' ||
           c == '_'
}

@private
is_octal_continue :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '7' ||
           c == '_'
}

@private
is_hexadecimal_continue :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '9' ||
           c >= 'a' && c <= 'f' ||
           c >= 'A' && c <= 'F' ||
           c == '_'
}

@private
is_decimal_continue :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '9' ||
           c == '_'             ||
           c == '.'
}

// -----------------------------------------------------------------------------
// String

@private
String :: struct {
    delimiter:   rune,
    first_index: int,
}

@private
set_string_mode :: proc(state: ^Lex_State, delimiter: rune) {
    state.mode = String {
        delimiter   = delimiter,
        first_index = state.index,
    }
}

@private
lex_string :: proc(
          c:      rune,
          state:  ^Lex_State,
    using mode:   ^String,
) {
    if c == delimiter {
        token := Token {
            kind     = .String,
            value    = nil,
            location = state.location,
            span     = Span { first_index, state.index }, 
        }

        set_normal_mode(state)
    }
}

@private
is_string_delimiter :: proc(c: rune) -> bool {
    return c == '\'' ||
           c == '"'  ||
           c == '`'
}

// -----------------------------------------------------------------------------
// Operators

@private
Operator :: struct {
    search:      Operator_Map,
    current:     Token_Kind,
    first_index: int,
}

@private
set_operator_mode :: proc(state: ^Lex_State) {
    state.mode = Operator {
        search      = OPERATOR_MAP,
        current     = .Invalid,
        first_index = state.index,
    }
}

@private
lex_operator :: proc(
          c:     rune,
          state: ^Lex_State,
    using mode:  ^Operator,
) {
    // Indicates whether or not the current character is part of a valid operator.
    found := false

    for i := 0;
        i < len(search) && !found;
        i += 1 
    {
        found = search[i].char == c

        if found {
            current = search[i].kind
            search  = search[i].next
        }
    }

    // Either the current character is not part of a valid operator, or we've reached
    // the end of the operator map. Either way, we should stop searching. At this point
    // we should construct a token for whatever we've found and reset the search state.
    if !found || search == nil {
        token := Token {
            kind     = current,
            value    = nil,
            location = state.location,
            span     = Span { first_index, state.index }, 
        }

        set_normal_mode(state)
        state.result = .Unprocessed
    }
}

@private
Operator_Map_Entry :: struct {
    kind: Token_Kind,
    char: rune,
    next: Operator_Map,
}

@private
Operator_Map :: []Operator_Map_Entry

@private
OPERATOR_MAP := Operator_Map {
    { .Plus,          '+', PLUS_MAP         },
    { .Minus,         '-', MINUS_MAP        },
    { .Asterisk,      '*', ASTERISK_MAP     },
    { .Solidus,       '/', SOLIDUS_MAP      },
    { .Percent,       '%', PERCENT_MAP      },
    { .Caret,         '^', CARET_MAP        },
    { .Ampersand,     '&', AMPERSAND_MAP    },
    { .Pipe,          '|', PIPE_MAP         },
    { .Tilde,         '~', TILDE_MAP        },
    { .Exclamation,   '!', EXCLAMATION_MAP  },
    { .Question,      '?', QUESTION_MAP     },
    { .Colon,         ':', COLON_MAP        },
    { .Semicolon,     ';', nil              },
    { .Dollar,        '$', nil              },
    { .Comma,         ',', nil              },
    { .Full_Stop,     '.', nil              },
    { .Equals,        '=', EQUALS_MAP       },
    { .Less_Than,     '<', LESS_THAN_MAP    },
    { .Greater_Than,  '>', GREATER_THAN_MAP },
    { .Left_Brace,    '{', nil              },
    { .Right_Brace,   '}', nil              },
    { .Left_Paren,    '(', nil              },
    { .Right_Paren,   ')', nil              },
    { .Left_Bracket,  '[', nil              },
    { .Right_Bracket, ']', nil              },
}

@private
PLUS_MAP := Operator_Map {
    { .Plus_Equals, '=', nil },
}

@private
MINUS_MAP := Operator_Map {
    { .Minus_Equals, '=', nil },
}

@private
ASTERISK_MAP := Operator_Map {
    { .Asterisk_Equals, '=', nil },
    { .Double_Asterisk, '*', DOUBLE_ASTERISK_MAP },
}

@private
DOUBLE_ASTERISK_MAP := Operator_Map {
    { .Double_Asterisk_Equals, '=', nil },
}

@private
SOLIDUS_MAP := Operator_Map {
    { .Solidus_Equals, '=', nil },
}

@private
PERCENT_MAP := Operator_Map {
    { .Percent_Equals, '=', nil },
}

@private
CARET_MAP := Operator_Map {
    { .Caret_Equals, '=', nil },
}

@private
AMPERSAND_MAP := Operator_Map {
    { .Ampersand_Equals, '=', nil },
    { .Double_Ampersand, '&', DOUBLE_AMPERSAND_MAP },
}

@private
DOUBLE_AMPERSAND_MAP := Operator_Map {
    { .Double_Ampersand_Equals, '=', nil },
}

@private
PIPE_MAP := Operator_Map {
    { .Pipe_Equals, '=', nil },
    { .Pipe_Greater_Than, '>', nil },
    { .Double_Pipe, '|', DOUBLE_PIPE_MAP },
}

@private
DOUBLE_PIPE_MAP := Operator_Map {
    { .Double_Pipe_Equals, '=', nil },
}

@private
TILDE_MAP := Operator_Map {
    { .Tilde_Equals, '=', nil },
}

@private
EXCLAMATION_MAP := Operator_Map {
    { .Exclamation_Equals, '=', nil },
}

@private
QUESTION_MAP := Operator_Map {
    { .Question_Equals, '=', nil },
}

@private
COLON_MAP := Operator_Map {
    { .Double_Colon, ':', nil },
}

@private
EQUALS_MAP := Operator_Map {
    { .Double_Equals, '=', nil },
}

@private
LESS_THAN_MAP := Operator_Map {
    { .Less_Than_Equals, '=', LESS_THAN_EQUALS_MAP },
    { .Double_Less_Than, '<', DOUBLE_LESS_THAN_MAP },
}

@private
LESS_THAN_EQUALS_MAP := Operator_Map {
    { .Space_Ship, '>', nil },
}

@private
DOUBLE_LESS_THAN_MAP := Operator_Map {
    { .Double_Less_Than_Equals, '=', nil },
}

@private
GREATER_THAN_MAP := Operator_Map {
    { .Greater_Than_Equals, '=', nil },
    { .Double_Greater_Than, '>', DOUBLE_GREATER_THAN_MAP },
}

@private
DOUBLE_GREATER_THAN_MAP := Operator_Map {
    { .Double_Greater_Than_Equals, '=', nil },
}


