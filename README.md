# TypedJavaScript (tjs)

A new language that compiles to JavaScript that isn't as shit as Typescript.
It supports JS pass through, but is not a superset. TJS and JS code cannot be combined in a single file,
but the compiler allows importing from JS code that has a type definitions file. It also comes packaged
with a tool to automatically convert a JS file to a TJS file. It will do its best to identify the types.

## Types

Basic types. These are the basic types that are supported by JavaScript.
The `int` type is a runtime type. The compiler will insert `|0` to force the value to be an integer.

```ts
bool
num
int
bigint
str
obj

void // One value: undefined
any  // Could be anything, requires a cast to use. e.g. `cast(boolean) a`
```

Like Typescript, TJS supports type unions and literal types. The union syntax is a little different
though.

```ts
// TS:
type U = string | number;

// TJS:
type U = union { string number }
```

With literal types

```ts
// TS:
type U = "hello" | "world";

// TJS:
type U = union { "hello" "world" }
```

The `keyof` keyword can be used on an object type to generate a union of all the keys.

```ts
type HTML_Element_Tag_Name_Map = object {
    a       HTML_Anchor_Element
    abbr    HTML_Element
    address HTML_Element
    area    HTML_Area_Element
    article HTML_Element
    aside   HTML_Element
    audio   HTML_Audio_Element
    b       HTML_Element
}

fn create_element(document Document, element keyof HTML_Element_Tag_Name_Map) HTML_Element_Tag_Name_Map[element] {}
```


## Variables

TJS uses both `let` and `const`. It has no support for `var`. However, TJS `const` is more strict than
JS `const`. In JS `const` is useless for objects since it doesn't stop mutation of the object, just
reassignment to the variable.

```js
// This is valid JS and TJS code:
let a = 10
a = 20

// This is valid JS and TJS code:
const b = 20
// Cannot reassign a constant.
// b = 30 

// This is valid JS, but not valid TJS
const c = { p: 20 }
c.p = 30
```

## Functions

TJS has a single function type. It has no need for the JS arrow function

```js
// Function declarations have the following syntax:
// The `fn` keyword declares a function
// |  The name of the function follows the `fn` keyword
// |  |    Argument names followed by the argument type.
// |  |    |   There is no special separator
// |  |    |   |     The return type follows the closing `)`
// |  |    |   |     |     The function body can be a block or a single expression
// |  |    |   |     |     |
// V  V    V   V     V     V
   fn name(arg type) type; {}
```

TJS doesn't support the `return` keyword. Instead functions return their last expresion if it matches
the declared return type. If the return type is anything other than `void` the compiler will issue an
error when the final expression doesn't match. 

```js
// TJS:
fn add(a, b integer) integer; a + b

// JS:
function add(a, b) {
    return a + b;
}
```

## Generator and Async Functions

TJS supports generator, async and async generator functions.

```js
// Generator functions 
fn*       name() void; {} // A generator
fn  async name() void; {} // An async function
fn* async name() void; {} // An async generator
```

## Classes 

TJS supports a limited form of OOP. Similar to that found in Go, Switft or Rust. It has a `type` keyword
that is used to defined the type of an object. It then uses `impl` blocks to add functionality to the
type. Functions declared within an `impl` block can specify either `const self`, `let self` or `<empty>`
as their first argument. 

To demonstrate how this works, imagine your application has the following JS class:

```js
// JS:
class Rectangle {
    constructor(width, height) {
        this.width  = width;
        this.height = height;
    }
    
    // Getter
    get area() {
        return this.calc_area();
    }
    
    // Method
    calc_area() {
        return this.height * this.width;
    }

    *getSides() {
        yield this.height;
        yield this.width;
        yield this.height;
        yield this.width;
    }
}
```

Usage from the TJS side would look like this:

```js
// TJS:
import { Rectangle } from "./Rectangle.js";

const r = Rectangle.new(10, 20)
console.log(r.area)       // 200
console.log(r.calcArea()) // 200

for(r.getSides); {
    console.log(:$) // 20, 10, 20, 10
}
```

Translation to TJS would look like this:

```js
type Rectangle {
    width  number
    height number
}

impl Rectangle {
    fn new(width number, height number) Self; {
        Self { width, height }
    }

    fn calc_area(self) number; self.height * self.width
    fn get  area(self) number; self.calc_area()

    fn* get_sides(self) number; {
        yield self.height
        yield self.width
        yield self.height
        yield self.width
    }
}
```