package lexer

// -----------------------------------------------------------------------------
// Lexer

// Need a better name for this
Result :: enum {
    Processed,
    Unprocessed,
}

Mode :: enum {
    Normal,
    Identifier,
    Number,
    String,
    Operator,
}

Lex_State :: union {
    Normal_Lex_State,
    Identifier_Lex_State,
    Number_Lex_State,
    String_Lex_State,
    Operator_Lex_State,
}

lex_source :: proc(source: string) {
    current_location: Location
       next_location: Location

    mode := Mode.Normal

    lex_state: Lex_State

    processed: for c, i in source {
        current_location = next_location
        
        next_location.column += 1

        if c == '\n' {
            next_location.column = 1
            next_location.line  += 1
        }

        unprocessed: for {
            result := Result.Processed

            switch mode {
                case .Normal:     lex_normal    (&lex_state, c, &mode, &result)
                case .Identifier: lex_identifier(&lex_state, c, &mode, &result)
                case .Number:     lex_number    (&lex_state, c, &mode, &result)
                case .String:     lex_string    (&lex_state, c, &mode, &result)
                case .Operator:   lex_operator  (&lex_state, c, &mode, &result)
            }

            switch result {
                case .Processed:   continue processed
                case .Unprocessed: continue unprocessed
            }
        }
    }
}

// -----------------------------------------------------------------------------
// Normal

Normal_Lex_State :: struct {
    
}

lex_normal :: proc(
    state:  ^Lex_State,
    c:      rune,
    mode:   ^Mode,
    result: ^Result,
) {
    switch {
        case is_white_space(c):
            // Skip white space characters

        case is_identifier_start(c):
            mode^   = .Identifier
            result^ = .Unprocessed

        case is_numeric_start(c):
            mode^   = .Number
            result^ = .Unprocessed

        case is_single_quote(c):
            mode^   = .String

        case is_double_quote(c):
            mode^   = .String

        case:
            mode^   = .Operator
            result^ = .Unprocessed
    }
}

is_white_space :: #force_inline proc(c: rune) -> bool {
    return c <= ' '
}

// -----------------------------------------------------------------------------
// Identifier

Identifier_Lex_State :: struct {
    
}

lex_identifier :: proc(
    state:  ^Lex_State,
    c:      rune,
    mode:   ^Mode,
    result: ^Result,
) {
    if is_identifier_continue(c) {
        result^ = .Unprocessed
    }
}

is_identifier_start :: #force_inline proc(c: rune) -> bool {
    return c >= 'a' && c <= 'z' ||
           c >= 'A' && c <= 'Z' ||
           c == '_'             ||
           c == '$'
}

is_identifier_continue :: #force_inline proc(c: rune) -> bool {
    return is_identifier_start(c) ||
           is_numeric_start(c)
}

// -----------------------------------------------------------------------------
// Number

Number_Lex_State :: struct {
    
}

lex_number :: proc(
    state:  ^Lex_State,
    c:      rune,
    mode:   ^Mode,
    result: ^Result,
) {
    if is_numeric_continue(c) {
        result^ = .Unprocessed
    }
}

is_numeric_start :: #force_inline proc(c: rune) -> bool {
    return c >= '0' && c <= '9'
}

is_numeric_continue :: #force_inline proc(c: rune) -> bool {
    return is_numeric_start(c) ||
           c == '_'
}

// -----------------------------------------------------------------------------
// String

String_Lex_State :: struct {
    delimiter: rune,
}

lex_string :: proc(
    state:  ^Lex_State,
    c:      rune,
    mode:   ^Mode,
    result: ^Result,
) {
    if is_single_quote(c) {
        result^ = .Unprocessed
    }
}

is_single_quote :: proc(c: rune) -> bool {
    return c == '\''
}

is_double_quote :: proc(c: rune) -> bool {
    return c == '"'
}

// -----------------------------------------------------------------------------
// Operators

Operator_Lex_State :: struct {
    search:  []Operator,
    current: Token_Kind,
}

lex_operator :: proc(
    state:  ^Lex_State,
    c:      rune,
    mode:   ^Mode,
    result: ^Result,
) {
    state, ok := state.(Operator_Lex_State)

    if !ok {
        state = Operator_Lex_State {
            search  = nil,
            current = .Invalid,
        }
    }

    using state

    if search == nil {
        search  = OPERATOR_MAP
        current = .Invalid
    }

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
            location = first_character_location,
            span     = Span { first_index, last_index }, 
        }

        mode^   = .Normal
        result^ = .Unprocessed
        search  = nil
    }
}

@private
Operator :: struct {
    kind: Token_Kind,
    char: rune,
    next: []Operator,
}

@private
OPERATOR_MAP := []Operator {
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
PLUS_MAP := []Operator {
    { .Plus_Equals, '=', nil },
}

@private
MINUS_MAP := []Operator {
    { .Minus_Equals, '=', nil },
}

@private
ASTERISK_MAP := []Operator {
    { .Asterisk_Equals, '=', nil },
    { .Double_Asterisk, '*', DOUBLE_ASTERISK_MAP },
}

@private
DOUBLE_ASTERISK_MAP := []Operator {
    { .Double_Asterisk_Equals, '=', nil },
}

@private
SOLIDUS_MAP := []Operator {
    { .Solidus_Equals, '=', nil },
}

@private
PERCENT_MAP := []Operator {
    { .Percent_Equals, '=', nil },
}

@private
CARET_MAP := []Operator {
    { .Caret_Equals, '=', nil },
}

@private
AMPERSAND_MAP := []Operator {
    { .Ampersand_Equals, '=', nil },
    { .Double_Ampersand, '&', DOUBLE_AMPERSAND_MAP },
}

@private
DOUBLE_AMPERSAND_MAP := []Operator {
    { .Double_Ampersand_Equals, '=', nil },
}

@private
PIPE_MAP := []Operator {
    { .Pipe_Equals, '=', nil },
    { .Pipe_Greater_Than, '>', nil },
    { .Double_Pipe, '|', DOUBLE_PIPE_MAP },
}

@private
DOUBLE_PIPE_MAP := []Operator {
    { .Double_Pipe_Equals, '=', nil },
}

@private
TILDE_MAP := []Operator {
    { .Tilde_Equals, '=', nil },
}

@private
EXCLAMATION_MAP := []Operator {
    { .Exclamation_Equals, '=', nil },
}

@private
QUESTION_MAP := []Operator {
    { .Question_Equals, '=', nil },
}

@private
COLON_MAP := []Operator {
    { .Double_Colon, ':', nil },
}

@private
EQUALS_MAP := []Operator {
    { .Double_Equals, '=', nil },
}

@private
LESS_THAN_MAP := []Operator {
    { .Less_Than_Equals, '=', LESS_THAN_EQUALS_MAP },
    { .Double_Less_Than, '<', DOUBLE_LESS_THAN_MAP },
}

@private
LESS_THAN_EQUALS_MAP := []Operator {
    { .Space_Ship, '>', nil },
}

@private
DOUBLE_LESS_THAN_MAP := []Operator {
    { .Double_Less_Than_Equals, '=', nil },
}

@private
GREATER_THAN_MAP := []Operator {
    { .Greater_Than_Equals, '=', nil },
    { .Double_Greater_Than, '>', DOUBLE_GREATER_THAN_MAP },
}

@private
DOUBLE_GREATER_THAN_MAP := []Operator {
    { .Double_Greater_Than_Equals, '=', nil },
}


