package lexer

Token_Kind :: enum {
    Invalid,
    Identifier,

    // Single Token Literals
    // Object and Array literals can't be represented by a single token
    Integer,
    Big_Integer,
    Float,
    String,
    Boolean,

    // Keywords
    Import,
    Export,
    If,
    Else,
    For,
    While,
    Type,
    Object,
    Union,
    Enum,
    Fn,
    Self,
    Self_Type,

    // Operators
    Plus,                       // +
    Plus_Equals,                // +=
    Minus,                      // -
    Minus_Equals,               // -=
    Asterisk,                   // *
    Asterisk_Equals,            // *=
    Double_Asterisk,            // **
    Double_Asterisk_Equals,     // **=
    Solidus,                    // /
    Solidus_Equals,             // /=
    Percent,                    // %
    Percent_Equals,             // %=
    Caret,                      // ^
    Caret_Equals,               // ^=
    Ampersand,                  // &
    Ampersand_Equals,           // &=
    Double_Ampersand,           // &&
    Double_Ampersand_Equals,    // &&=
    Pipe,                       // |
    Pipe_Equals,                // |=
    Pipe_Greater_Than,          // |>
    Double_Pipe,                // ||
    Double_Pipe_Equals,         // ||=
    Tilde,                      // ~
    Tilde_Equals,               // ~=
    Exclamation,                // !
    Exclamation_Equals,         // !=
    Question,                   // ?
    Question_Equals,            // ?=
    Colon,                      // :
    Double_Colon,               // ::
    Semicolon,                  // ;
    Dollar,                     // $
    Comma,                      // ,
    Full_Stop,                  // .
    Equals,                     // =
    Double_Equals,              // ==
    Less_Than,                  // <
    Less_Than_Equals,           // <=
    Space_Ship,                 // <=>
    Double_Less_Than,           // <<
    Double_Less_Than_Equals,    // <<=
    Greater_Than,               // >
    Greater_Than_Equals,        // >=
    Double_Greater_Than,        // >>
    Double_Greater_Than_Equals, // >>=
    Left_Brace,                 // {
    Right_Brace,                // }
    Left_Paren,                 // (
    Right_Paren,                // )
    Left_Bracket,               // [
    Right_Bracket,              // ]
}

Token_Value :: union {
    f64,
    i64,
    bool,
}

Location :: struct {
    column: int,
    line:   int,
}

Span :: struct {
    start: int,
    end:   int,
}

Token :: struct {
    kind:     Token_Kind,
    value:    Token_Value,
    location: Location,
    span:     Span,
}
