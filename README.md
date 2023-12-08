# TypedJavaScript (tjs)

A new language that compiles to JavaScript or WebAssembly. That is than [Typescript or AssemblyScript](#typescript-and-assemblyscript) easier to write robust code in.

When compiling to JS it supports JS pass through, but it is not a superset. TJS and JS code cannot be combined in a single file, but the compiler allows importing from JS code that has a type definitions file. It also comes packaged with a tool to automatically convert a JS file to a TJS file. It will do its best to identify the types.

We also plan to support compiling JS to Wasm if type definitions exist 

---

# Roadmap

- [ ] Compile to JS
    - [ ] Source Maps
    - [ ] JS Pass Through
- [ ] Compile to Wasm
    - [ ] Debug Info
    - [ ] Optimisation Levels

---

# Language

The syntax of the language borrows from JavaScript where it makes sense and deviates otherwise. We try not to be different for the sake of it, but that doesn't stop us from experimenting if we think it will improve something.

## Basic Types and Values

Since we compile to both JS and Wasm we need to support a wider range of types than Typescript provides. This is somewhere that AssemblyScript does pretty well so we're going to be pretty close, if not the same.

### Integer Types

WebAssembly support i32 and i64. The signed-ness of the value depends on the operation. TJS exposes this through separate types e.g. u32 vs i32. This is more familiar to programmers of higher level languages. You, dear reader, may also notice that TJS support arbitrary sized integers. This is simply a way to limit the maximum value for an integer. It doesn't change the underlying representation.

| TypedJavaScript Type | WebAssembly Type | JavaScript Type |
| ---                  | ---              | ---             |
| i1  - i32            | i32              | number          |
| i33 - i53            | i64              | number          |
| i54 - i64            | i64              | bigint          |
| u1  - u32            | i32              | number          |
| u33 - u53            | i64              | number          |
| u54 - u64            | i64              | bigint          |
| bool                 | i32              | boolean         |

Smaller integer types can always be assigned to larger integer types without a cast. This is because the larger type can represent all possible values of the smaller type. The same is not true the other way around and therefore requires a cast e.g.

```ts
const a: u32 = 10;
const b: u8  = cast(u8) a;
const c: u64 = a;
```

Integers can be expressed in TJS using the following formats:

| Name        | Range | Floating Point |
| ---         | ---   | ---            |
| Decimal     | 0-9   | true           |
| Hexadecimal | 0-F   | false          |
| Octal       | 0-7   | false          |
| Binary      | 0-1   | false          |

Some examples:

```ts
const dec: u32  =  100;
const hex: u8   =  0xAB; // Also supports lowercase (0xff)
const oct: i32  = -0o71;
const bin: u3   =  0b101;
const can: bool =  true;
```

Just like modern JS, literals with a leading 0 do not cause the value to be interpreted as an octal. Once upon a time in JS `040` would result in `32`. Luckily this is no longer the case and we do not make the same mistake.

### Floating Point Types

| TypedJavaScript Type | WebAssembly Type | JavaScript Type |
| ---                  | ---              | ---             |
| f32                  | f32              | number          |
| f64                  | f64              | number          |

The assignment rules for integers also apply to floating point numbers.

Assigning from a floating point to an integer and visa versa always requires a cast. 

Floating point examples:

```ts
const float1: f32 = 0.14159
const float2: f64 = 100.0
```

### SIMD Vector Types

SIMD is not fully supported in all WebAssembly runtimes, so the compiler has a flag `--enable simd`. TJS will always output code for SIMD operations, but if the flag is omitted the operations will be emulated using arrays. The compiler flag only applies to the Wasm target. If your code is targeting JS the result is always emulated. The SIMD vector types are represented in JS as TypedArrays. There is no way to perform SIMD operations in JS, so this is the best we can do. We just have to hope that the JS engines realise what we're trying to do and optimise it to SIMD operations themselves.

| TypedJavaScript Type | WebAssembly Type | JavaScript Type |
| ---                  | ---              | ---             |
| u8x16                | v128             | Uint8Array      |
| u16x8                | v128             | Uint16Array     |
| u32x4                | v128             | Uint32Array     |
| u64x2                | v128             | BigUint64Array  |
| i8x16                | v128             | Int8Array       |
| i16x8                | v128             | Int16Array      |
| i32x4                | v128             | Int32Array      |
| i64x2                | v128             | BigInt64Array   |
| f32x4                | v128             | Float32Array    |
| f64x2                | v128             | Float64Array    |

SIMD Vector types can only be assigned to themselves. In JS This results in a new array 

### String Types

In JS mode the string are represented as utf16 as per the ECMAScript standard. In Wasm mode they are represented as utf8 since this is better for interoperability with every other programming language and environment (except Windows). Because of this duality and because we want to support JS interop strings are immutable.

| TypedJavaScript Type | WebAssembly Type | JavaScript Type |
| ---                  | ---              | ---             |
| str                  | (ref string)     | string          |

TJS supports the same string literals as JS.

```js
const s1: str = "This is a string"
const s2: str = 'This is also a string'

const interpolation: str = "that allows interpolation"
const back_tick_str: str = `This is a string ${interpolation}`
```

### Other Types

| TypedJavaScript Type | WebAssembly Type | JavaScript Type |
| sym                  |                  | Symbol          |
| obj                  |                  | Object          |
| fn();                |                  | Function        |
| []                   |                  | Array           |
| any                  |                  | N/A             |
| void                 |                  | undefined       |

### Literal Types

`TODO`: `const a: "hello" = "hello"`

## Compound Types and Values

`TODO`:
### Object
### Enum
### Union
### Bit_Set

<!-- 

Literal types are a convenience for the programmer. They allow the creation of APIs that require specific values to be passed.

```ts
// TS:
type U = "hello" | "world";

// TJS:
type U = union { "hello" "world" }
```

The `key_of` keyword can be used on an object type to generate a union of all the keys.

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

fn create_element(document Document, element key_of HTML_Element_Tag_Name_Map) HTML_Element_Tag_Name_Map[element] {}
``` -->

## Variables and Type Inference

TJS variable declarations look very similar to those of JS. It uses both `let` and `const`. `var` on the other hand is a long forgotten memory; and something we're happy about forgetting.

### Let vs Const

TJS `const` is more strict than JS `const`. In JS `const` only applies to the declaration itself. It doesn't stop deeper mutation of objects or arrays, just reassignment to the variable. TJS `const` applies all the way down.

For a concrete example consider this JS code:

```js
let   a = 10
const b = 20
const c = { p: 30 }

// The following are all valid
a   = 20
c.p = 100

// This is not
b = 30 // invalid assignment to const
```

Now consider the same thing in TJS:

```ts
let   a: i32 = 10;
const b: i32 = 20;
const c: object { p i32 } = { p = 30 }

// Only the assignment to the 'a' is valid
a = 20

// These are not
c.p = 100
b   = 30
```

### Type Inference

In the above example we added type annotations to the code to let TJS know what our intentions were. This is only required in cases were it is otherwise know inferable. If, for example, we have a function that is declared with two parameters, one `string` and one `i32` we could write the following:

```ts
const first  = "something"
const second = 20

f(first, second)
```

In this case `first`'s type is inferred to be a string because there is no other type it could be. At first, `second`'s type is inferred to be `<literal number>` which can be coerced into any numeric type.

## Functions

We just mentioned functions, but didn't show how they're defined. This is one of the areas of TJS that diverges significantly from JS. The reason for this is mostly convenience. In old JS we only had `function` and it came in two forms: `function f` and `const f = function`. These two forms had the same semantics and neither of them played very well with `this`. Then came `() =>`.

`TODO`: Talk about multiple styles, semantics and weird edge cases.

TJS uses a single syntax for all of these. This removes the style wars and the annoying interview questions about arrow vs normal functions. Can anyone remember all the [differences](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Arrow_functions)?

### Plain Functions

`TODO`: Some thinking about interop. Calling a TJS function from JS and visa versa

Syntax:

```js
fn no_return(); {}
fn return_int() i32; { 10 }

fn one_arg(a i32); {}
fn two_args(a string, b i32); {}
fn same_type(a, b bool); {}
```

The eagle eyed among you may have spotted the lack of a `return` keyword. TJS does not support the `return` keyword at all. Instead functions return their last expression if it matches the declared return type. If the return type is anything other than `void` the compiler will issue an error when the final expression doesn't match. The `{}` is also an expression in TJS so, much like an arrow function, a single expression TJS function doesn't require them.  

```js
fn add(a, b f64) f64; a + b
```

It might be a little more obvious why the `;` makes an appearance here. Originally we were going to use `=>` instead because it's more familiar to JS developers, but we prefer the look of the `;`:

```js
fn add(a, b f64) f64 => a + b
fn add(a, b f64) f64;   a + b
```

### Generator, Async and Async Generator Functions

TJS supports [generator](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/function*), [async](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function) and [async generator](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/async_function*) functions. These work as you would expect from JS.

The syntax for declaring then is as follows. The only real difference is that the async keyword is on the right hand side. This makes the parser easier to write.

```js
// Generator functions 
fn*       name() void; {} // A generator
fn  async name() void; {} // An async function
fn* async name() void; {} // An async generator
```

## Object Oriented Programming 

TJS supports a limited form of OOP. Similar to that found in Go, Switft or Rust. It has a `type` keyword that is used to defined the type of an object. It then uses `impl` blocks to add functionality to the type. Functions declared within an `impl` block can specify either `self`, `self` or `<empty>` as their first argument. 

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
type Rectangle = object {
    width  f64
    height f64
}

impl Rectangle {
    fn new(width, height f64) Self; {
        Self { width, height }
    }

    fn calc_area(const self) f64; self.height * self.width
    fn get  area(const self) f64; self.calc_area()

    fn* get_sides(const self) f64; {
        yield self.height
        yield self.width
        yield self.height
        yield self.width
    }
}
```

A TJS Types file for the above class would look like this:

```js
type Rectangle = object {
    width  f64
    height f64
}

impl Rectangle {
    fn new(width, height f64) Self;

    fn calc_area(const self) f64;
    fn get  area(const self) f64;

    fn* get_sides(const self) f64;
}
```

---

# Typescript and AssemblyScript

Typescript and AssemblyScript exists, so why TypedJavaScript?

It is the belief of the TypedJavaScript Team that neither language really lends itself to producing robust code.

This section of the document is going to focus on the perceived issues of these two language. There are many things to like about both and if you want to learn more about them you should visit [Typescript](https://www.typescriptlang.org/) and [AssemblyScript](https://www.assemblyscript.org/) respectively.

## Typescript

Having worked extensively with Typescript since it was release in 2012 we have come to understand its strengths and weaknesses. It is a fact that Typescript is a hugely successful project and provides a lot of benefit to the many teams using it. It's also a fact that Typescript is not perfect. It is inevitable that any long lived project that will accumulate cruft. A few surface level examples: `any` vs `unknown` and `@ts-ignore` vs `@ts-expect-error`.

The main reasons for breaking away from Typescript are:

1. [Its type level syntax is hard to read and write](#type-level-syntax)
2. [Its goal of not emitting different JS based on type information](#type-info-emit)

### Type Level Syntax

Typescript's type system is quite powerful, but the syntax for manipulating it is both hard to read and non-obvious. Consider the following example:

```ts
type DeepReadonly<T>
    = T extends Array<infer A>        ? ReadonlyArray<DeepReadonly<A>>
    : T extends Map<infer K, infer V> ? ReadonlyMap<DeepReadonly<K>, DeepReadonly<V>>
    : T extends Set<infer S>          ? ReadonlySet<DeepReadonly<S>>
    : { readonly [I in keyof T]: DeepReadonly<T[I]> };

type A = DeepReadonly<{ p: number }[]>; // ReadonlyArray<readonly { readonly p: number }[]>
```

The above type is an example of a mapped type. It does to types what `as const` does to literals. Not only is this hard to read, it also doesn't handle tuple types properly. Given this type: `DeepReadonly<[number, { p: number }]>` one would expect `readonly [number, { readonly p: number }]`, but instead it results in `readonly (number | { readonly p: number })[]`. So it loses the tuple-ness of the input. At the time of writing it's impossible to handle this in a generic way. One could add entries for `T extends [infer A]`, `T extends [infer A, infer B]`, etc but that gets tedious and unwieldy very quickly.

TJS uses imperative syntax and with a `Type_Info` API for manipulating the type system. The result of this is that TJS has a single language to learn instead of two. Here is the above example in TJS. (Not that it's required because `const a` is already deep readonly.):

```rust
fn deep_readonly(T type) Type_Info; {
    let info: Type_Info = info_of T

    if {
        is_array_type(info); {
            result.element_info = deep_readonly(info.element_info)
        }

        is_tuple_type(info); {
            for(each) info.elements {
                :value.info = deep_readonly(:value.info)
            }
        }

        is_object_type(info); {
            for(each) info.members {
                :key.info   = deep_readonly(:key.info)
                :value.info = deep_readonly(:value.info)
            }
        }
    } else {
        // This isn't an actual API. The "const"-ness of a type depends on the usage.
        info.is_readonly = true
    }

    result
}

type A = deep_readonly(object { p f64 })
```

The first thing someone may note is that the TJS version is longer. This is true, but that tends to be the case when comparing imperative and declarative styles of code. The problem for Typescript is that most code someone writes is imperative. For a developer to get good at the declarative type system API they must first internalise an entirely new way of thinking. TJS tries to avoid this by using the same style of code for all aspects of the programming language. We do not want to lock off parts of the language to only those few who can wrap their heads around special type level programming.

To be fair to Typescript, it is not the only language that does this. C++ has its template meta programming, Rust has its generics and trait bounds, etc. That said. We're in competition with Typescript and so we're aiming our criticism primarily in their direction.

### Type Info Emit

`TODO`: constant folding, conditional compilation, true generic programming

## Assembly Script

AssemblyScript is an interesting idea. It's high level goals are very similar to TypedJavaScript's. We both want to create a language that can emit both JavaScript and WebAssembly. We differ in our approach. AssemblyScript wants to stick as closely as it can to Typescript's syntax while we're not worried about deviating from that.

There are a few key areas that we believe TypedJavaScript is better than AssemblyScript:

1. [Portable conversions](#portable-conversions)
2. [Portable overflows](#portable-overflows)

### Portable Conversions

The failing here is shown quite well in their own examples:

```ts
// non-portable
let someFloat: f32 = 1.5
let someInt: i32 = <i32>someFloat
```
vs
```ts
// portable
let someFloat: f32 = 1.5
let someInt: i32 = i32(someFloat)
```

Both of these examples do the same thing as far as AssemblyScript is concerned, but compile to different JS. The `non-portable` version just removes the cast because it uses the Typescript compiler. This means that you essentially can't use `<T>` or `as T` style casts.

TJS solves this by always emitting "portable" conversion where required.

## Portable Overflows

Again, the failing is shown own their own site with their own examples:

```ts
// non-portable
let someU8: u8 = 255
let someOtherU8: u8 = someU8 + 1
```
vs
```ts
// portable
let someU8: u8 = 255
let someOtherU8: u8 = u8(someU8 + 1)
```

The issue this time is that when compiling to JS using the Typescript compiler the first example results in `someOtherU8` being set to `256`. The ramifications of this are significant. If you wish to write portable code you must wrap all maths operations in "portable" casts. Not only is this error prone it's not obvious to unfamiliar developers. If an experienced Typescript developer joins an AssemblyScript codebase for the first time it seems redundant to wrap a `u8 + u8` in a cast to `u8`. They may remove this cast and it may get past code review. Even if it doesn't it's inconvenient for more experienced AssemblyScript developers to constantly have to be on the look out for this.  

TJS solves this by doing what all sensible languages do. Checking for overflow at compile time and inserting checks where it can't be sure. When the optimisation level is increased these checks are removed. The language also provides functions and types to allow developers to specify what should happen in any given case.

See: [`wrapping_add`](), [`saturating_add`](), [`overflowing_add`](), [`checked_add`](), [`Wrapping(T)`](), [`Saturating(T)`]().
