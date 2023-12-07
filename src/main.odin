package main

import "core:fmt"
import "core:os"

main :: proc() {
    if len(os.args) >= 2 {
        name := os.args[1]
        
        if file, ok := os.read_entire_file(name); ok {
            contents := cast(string) file
            
            fmt.println(contents)

        } else {
            fmt.println("Error reading file")
        }
    } else {
        fmt.println("Usage: tjs <filename>")
    }
}
