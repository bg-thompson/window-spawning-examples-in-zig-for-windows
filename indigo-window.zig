//////////////////////////////////////////////////////////////////////////////////
// This is an elementary program in Zig which spawns an indigo window on the    //
// Windows operating system and prints out window messages it receives.         //
//                                                                              //
// This program does not use any window-spawning libraries like GLFW or SDL; it //
// is completely self-contained.                                                //
//                                                                              //
// This file can be compiled and run with the Zig 0.13.0 compiler using the     //
// command:                                                                     //
//                                                                              //
//     zig run indigo-window.zig                                                //
//                                                                              //
// To compile the program with optimizations, use the command:                  //
//                                                                              //
//     zig build-exe indigo-window.zig -Doptimize=ReleaseFast                   //
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
const ATOM      = w32.ATOM;      comptime { check_type_eq(ATOM,    u16);   }
const BOOL      = w32.BOOL;      comptime { check_type_eq(BOOL,    c_int); }
const DWORD     = w32.DWORD;     comptime { check_type_eq(DWORD,   u32);   }
const HANDLE    = w32.HANDLE;    // Defined as *anyopaque{}.
const HBRUSH    = w32.HBRUSH;    // Defined as *opaque{}.
const HCURSOR   = w32.HCURSOR;   // Defined as *opaque{}.
const HICON     = w32.HICON;     // Defined as *opaque{}.
const HINSTANCE = w32.HINSTANCE; // Defined as *opaque{}.
const HMENU     = w32.HMENU;     // Defined as *opaque{}.
const HWND      = w32.HWND;      // Defined as *opaque{}.
const LONG      = w32.LONG;      comptime { check_type_eq(LONG,    i32);   }
const LPARAM    = w32.LPARAM;    comptime { check_type_eq(LPARAM,  isize); }
const LPCSTR    = w32.LPCSTR;    comptime { check_type_eq(LPCSTR,  [*:0] const u8); }
const LPVOID    = w32.LPVOID;    // Defined as *anyopaque;
const LRESULT   = w32.LRESULT;   comptime { check_type_eq(LRESULT, isize); }
const UINT      = w32.UINT;      comptime { check_type_eq(UINT,    c_uint);}
const WPARAM    = w32.WPARAM;    comptime { check_type_eq(WPARAM,  usize); }

const POINT     = extern struct { x: LONG, y: LONG };
const WNDPROC   = *const fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

// Constants
const FALSE = 0;

const IDC_CROSS    = @as(LPCSTR, @ptrFromInt(32515)); // Per WinUser.h
const IMAGE_CURSOR   : UINT = 2;                      // ""
const LR_DEFAULTSIZE : UINT = 0x0000_0040;            // ""
const LR_SHARED      : UINT = 0x0000_8000;            // ""

const INDIGO_COLOR : DWORD = 0x00_82_00_4b; // W3C Indigo.

const CS_VREDRAW = 0x0001;
const CS_HREDRAW = 0x0002;

const PM_REMOVE : UINT = 0x0001; // WinUser.h.

const WM_DESTROY : UINT = 0x0002; // WinUser.h.
const WM_QUIT    : UINT = 0x0012; // ""

const WS_OVERLAPPED  : DWORD = 0x0000_0000; // WinUser.h
const WS_EX_TOPMOST  : DWORD = 0x0000_0008; // ""
const WS_MAXIMIZEBOX : DWORD = 0x0001_0000; // ""
const WS_MINIMIZEBOX : DWORD = 0x0002_0000; // ""
const WS_THICKFRAME  : DWORD = 0x0004_0000; // ""
const WS_SYSMENU     : DWORD = 0x0008_0000; // ""
const WS_CAPTION     : DWORD = 0x00C0_0000; // ""

const WS_OVERLAPPEDWINDOW : DWORD = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU
                                  | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX; // WinUser.h

// Other
const WINAPI  = w32.WINAPI;

// External Windows system procedures we need to call.
extern "user32" fn LoadImageA(hInst : ?HINSTANCE, name : LPCSTR, type : UINT, cx : c_int, cy : c_int, fuLoad : UINT) callconv(WINAPI) ?HANDLE;
extern "gdi32"  fn CreateSolidBrush(color : DWORD) callconv(WINAPI) HBRUSH;
extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;
extern "user32" fn AdjustWindowRectEx(lpRect : *RECT, dwStyle : DWORD, bMenu : BOOL, dwExStyle : DWORD) callconv(WINAPI) BOOL;

extern "user32" fn CreateWindowExA(dwExStyle : DWORD, lpClassName : ?LPCSTR, lpWindowName : ?LPCSTR, dwStyle : DWORD, X : c_int, Y : c_int, nWidth : c_int, nHeight : c_int, hWindParent : ?HWND, hMenu : ?HMENU, hInstance : HINSTANCE, lpParam : ?LPVOID) callconv(WINAPI) ?HWND;
extern "user32" fn ShowWindow(hWnd : HWND, nCmdShow : c_int) callconv(WINAPI) BOOL;

extern "user32" fn PeekMessageA(lpMsg : *const MSG, hWnd : ?HWND, wMsgFilterMin : UINT, wMsgFilterMax : UINT, wRemoveMsg : UINT) callconv(WINAPI) BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) BOOL;
extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;

extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;
extern "user32" fn DefWindowProcA(?HWND, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;

// Windows classes.
const RECT = w32.RECT;

const WNDCLASSEXA = extern struct {
    cbSize        : UINT = @sizeOf(WNDCLASSEXA),
    style         : UINT,
    lpfnWndProc   : WNDPROC,
    cbClsExtra    : i32 = 0,
    cbWndExtra    : i32 = 0,
    hInstance     : HINSTANCE,
    hIcon         : ?HICON,
    hCursor       : ?HCURSOR,
    hbrBackground : ?HBRUSH,
    lpszMenuName  : ?LPCSTR,
    lpszClassName : LPCSTR,
    hIconSm       : ?HICON,
};

const MSG = extern struct {
    hWnd     : ?HWND,
    message  : UINT,
    wParam   : WPARAM,
    lParam   : LPARAM,
    time     : DWORD,
    pt       : POINT,
    lPrivate : DWORD,
};

// Window procedure.
fn window_procedure(hWnd : ?HWND, message : UINT, wParam : WPARAM, lParam : LPARAM) callconv(.C) LRESULT {
  switch(message) {
      WM_DESTROY => {
          PostQuitMessage(0);
          return 0;
      },
      else => {},
    }
    return DefWindowProcA(hWnd, message, wParam, lParam);
}

// Main procedure. 
pub fn wWinMain(hInstance : w32.HINSTANCE, prevInstance : @TypeOf(null), cmdline : [*:0] u16, showcmd : c_int ) c_int {
    _ = prevInstance;
    _ = cmdline;

    // Load the window cursor, select the background.
    const cross_cursor = LoadImageA(null, IDC_CROSS, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
    const brush_color  = CreateSolidBrush(INDIGO_COLOR);

    // Specify and register the window class.
    const window_class = WNDCLASSEXA{
        .cbSize        = @sizeOf(WNDCLASSEXA),
        .style         = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc   = window_procedure,
        .hInstance     = hInstance,
        .hIcon         = null,
        .hCursor       = @ptrCast(cross_cursor),
        .hbrBackground = brush_color,
        .lpszMenuName  = null,
        .lpszClassName = "WindowClass1",
        .hIconSm       = null,
    };
    _ = RegisterClassExA(&window_class);

    // Specify the pixel dimensions of the window.
    var crect = RECT{.left = 0, .top = 0, .right = 450, .bottom = 150};

    // Adjust the pixel dimensions to factor in the size of the window borders.
    _ = AdjustWindowRectEx(&crect, WS_OVERLAPPEDWINDOW, FALSE, WS_EX_TOPMOST);
    
    // Create the window.
    const hWnd = CreateWindowExA(
        WS_EX_TOPMOST,
        "WindowClass1",
        "Indigo Window (with Window MSG printing)",
        WS_OVERLAPPEDWINDOW,
        100,                       // xpos
        100,                       // ypos
        crect.right  - crect.left, // width
        crect.bottom - crect.top,  // height
        null, 
        null,
        hInstance,
        null).?;

    _ = ShowWindow(hWnd, showcmd);

    // Main loop; handle window and thread messages.
    var msg : MSG = undefined;
    var peek_result : BOOL = PeekMessageA(&msg, null, 0, 0, PM_REMOVE);

    while (true) {
        if (peek_result != FALSE) {

            // Print details of the message received. 
            std.debug.print("MSG RECEIVED:\n{any}\n\n", .{msg}); //@debug
            
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
            if (msg.message == WM_QUIT) { break; }
        }
        peek_result = PeekMessageA(&msg, null, 0, 0, PM_REMOVE);
    }
    
    return @as(c_int, @intCast(msg.wParam));
}

// This (and the alias dictionary) are not necessary; but we include them so we
// know what on earth "LPCSTR" and the other type aliases actually are.
fn check_type_eq(t1 : type, t2 : type) void {
    if (t1 != t2) {
        const types_str = std.fmt.comptimePrint("{} / {}", .{t1, t2});
        @compileError("ERROR: Type mismatch:\n    " ++ types_str);
    }
}
