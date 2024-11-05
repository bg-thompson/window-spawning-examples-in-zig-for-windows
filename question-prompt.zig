//////////////////////////////////////////////////////////////////////////////////
// This is an elementary program in Zig which spawns a message box window on    //
// the Windows operating system.                                                //
//                                                                              //
// This program does not use any window-spawning libraries like GLFW or SDL; it //
// is completely self-contained.                                                //
//                                                                              //
// This file can be compiled and run with the Zig 0.13.0 compiler using the     //
// command:                                                                     //
//                                                                              //
//     zig run question-prompt.zig                                              //
//                                                                              //
// To compile the program with optimizations, use the command:                  //
//                                                                              //
//     zig build-exe question-prompt.zig -Doptimize=ReleaseFast                 //
//                                                                              //
// Created by Benjamin Thompson. Available at:                                  //
// https://github.com/bg-thompson/window-spawning-examples-in-zig-for-windows   //
// Last updated: 2024.11.05                                                     //
//                                                                              //
// Created for educational purposes. Used verbatim, it is probably unsuitable   //
// for production code.                                                         //
//////////////////////////////////////////////////////////////////////////////////

const std = @import("std");
const w32 = std.os.windows;

// Windows type aliases.
// We include a 'dictionary', checked at comptime, to confirm that the aliases are
// what we think they are (when possible).
const HWND   = w32.HWND;    // Defined as *opaque{}.
const LPCSTR = w32.LPCSTR;  comptime { check_type_eq(LPCSTR, [*:0] const u8); }
const UINT   = w32.UINT;    comptime { check_type_eq(UINT,   c_uint);         }
const INT    = w32.INT;     comptime { check_type_eq(INT,    c_int);          }

// Windows constants.
const MB_ICONQUESTION = 0x00000020; // From WinUser.h

// The external Windows system procedure we need to call. From:
// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-messageboxa
extern "user32" fn MessageBoxA(?HWND, LPCSTR, LPCSTR, UINT) callconv(WINAPI) INT;

// Other.
const WINAPI = w32.WINAPI;

// We use main() instead of wWinMain() here since we don't need any of the args
// that get passed into wWinMain() to spawn a prompt.
pub fn main() !void {
    const title = "Did you know...";
    const text  = "That this prompt was created in Zig using the MessageBoxA procedure?";
    _ = MessageBoxA(null, text, title, MB_ICONQUESTION);
}

// This (and the alias dictionary) are not necessary; but we include them so we
// know what on earth "LPCSTR" and the other type aliases actually are.
fn check_type_eq(t1 : type, t2 : type) void {
    if (t1 != t2) {
        const types_str = std.fmt.comptimePrint("{} / {}", .{t1, t2});
        @compileError("ERROR: Type mismatch:\n    " ++ types_str);
    }
}
