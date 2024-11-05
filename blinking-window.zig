//////////////////////////////////////////////////////////////////////////////////
// This is an elementary program in Zig which spawns a window whose color       //
// oscillates between pink and blue on the Windows operating system.            //
//                                                                              //
// NOTE: The OpenGL procedures used here are only the most BASIC ones; spawning //
// a general OpenGL context on Windows involves performing a huge number of     //
// ludicrous backflips, most (in)famously the creation of a 'dummy' window.     //
// To keep things simple we don't do that in this example.                      //
//                                                                              //
// This program does not use any window-spawning libraries like GLFW or SDL; it //
// is completely self-contained.                                                //
//                                                                              //
// This file can be compiled and run with the Zig 0.13.0 compiler using the     //
// command:                                                                     //
//                                                                              //
//     zig run blinking-window.zig                                              //
//                                                                              //
// To compile the program with optimizations, use the command:                  //
//                                                                              //
//     zig build-exe blinking-window.zig -Doptimize=ReleaseFast                 //
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
const ATOM      = w32.ATOM;      comptime { check_type_eq(ATOM,    u16);            }
const BOOL      = w32.BOOL;      comptime { check_type_eq(BOOL,    c_int);          }
const BYTE      = w32.BYTE;      comptime { check_type_eq(BYTE,    u8);             }
const DWORD     = w32.DWORD;     comptime { check_type_eq(DWORD,   u32);            }
const GLenum    = c_uint;        // Defined in GL.h
const HANDLE    = w32.HANDLE;    // Defined as *anyopaque{}.
const HBRUSH    = w32.HBRUSH;    // Defined as *opaque{}.
const HCURSOR   = w32.HCURSOR;   // Defined as *opaque{}.
const HDC       = w32.HDC;       // Defined as *opaque{}.
const HGLRC     = w32.HGLRC;     // Defined as *opaque{}.
const HICON     = w32.HICON;     // Defined as *opaque{}.
const HINSTANCE = w32.HINSTANCE; // Defined as *opaque{}.
const HMENU     = w32.HMENU;     // Defined as *opaque{}.
const HWND      = w32.HWND;      // Defined as *opaque{}.
const INT       = w32.INT;       comptime { check_type_eq(INT,     c_int);          }
const LONG      = w32.LONG;      comptime { check_type_eq(LONG,    i32);            }
const LPARAM    = w32.LPARAM;    comptime { check_type_eq(LPARAM,  isize);          }
const LPCSTR    = w32.LPCSTR;    comptime { check_type_eq(LPCSTR,  [*:0] const u8); }
const LPVOID    = w32.LPVOID;    // Defined as *anyopaque;
const LRESULT   = w32.LRESULT;   comptime { check_type_eq(LRESULT, isize);          }
const UINT      = w32.UINT;      comptime { check_type_eq(UINT,    c_uint);         }
const WORD      = w32.WORD;      comptime { check_type_eq(WORD,    u16);            }
const WPARAM    = w32.WPARAM;    comptime { check_type_eq(WPARAM,  usize);          }

const POINT     = extern struct { x: LONG, y: LONG };
const WNDPROC   = *const fn (hwnd: HWND, uMsg: UINT, wParam: WPARAM, lParam: LPARAM) callconv(WINAPI) LRESULT;

// Constants
const FALSE = 0;

const IDC_CROSS    = @as(LPCSTR, @ptrFromInt(32515)); // Per WinUser.h
const IMAGE_CURSOR   : UINT = 2;                      // ""
const LR_DEFAULTSIZE : UINT = 0x0000_0040;            // ""
const LR_SHARED      : UINT = 0x0000_8000;            // ""

const AQUAMARINE_COLOR : DWORD = 0x00D4FF7F; // W3C Aquamarine

const CS_VREDRAW = 0x0001;
const CS_HREDRAW = 0x0002;

const GL_COLOR_BUFFER_BIT : c_uint = 0x0000_4000; // Per GL.h
const GL_VERSION          : c_int  = 0x1F02;      // ""

const MB_ICONQUESTION = 0x00000020;

const PFD_DRAW_TO_WINDOW : DWORD = 0x0000_0004; // Per wingdi.h
const PFD_SUPPORT_OPENGL : DWORD = 0x0000_0020; // ""
const PFD_DOUBLEBUFFER   : DWORD = 0x0000_0001; // ""
const PFD_TYPE_RGBA      : BYTE  = 0;           // ""
const PFD_MAIN_PLANE     : BYTE  = 0;           // ""

const PM_REMOVE : UINT = 0x0001; // WinUser.h.

const WM_CREATE  : UINT = 0x0001;   // WinUser.h.
const WM_DESTROY : UINT = 0x0002; // ""
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

// Globals
var device_context_handle : HDC = undefined;

var program_stopwatch : std.time.Timer = undefined;
var initial_timestamp : u64 = undefined; // Timestamp in nanoseconds.
var current_timestamp : u64 = undefined; // Timestamp in nanoseconds.

// External Windows system procedures we need to call.
extern "user32"   fn LoadImageA(hInst : ?HINSTANCE, name : LPCSTR, type : UINT, cx : c_int, cy : c_int, fuLoad : UINT) callconv(WINAPI) ?HANDLE;
extern "gdi32"    fn CreateSolidBrush(color : DWORD) callconv(WINAPI) HBRUSH;
extern "user32"   fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) ATOM;
extern "user32"   fn AdjustWindowRectEx(lpRect : *RECT, dwStyle : DWORD, bMenu : BOOL, dwExStyle : DWORD) callconv(WINAPI) BOOL;

extern "user32"   fn CreateWindowExA(dwExStyle : DWORD, lpClassName : ?LPCSTR, lpWindowName : ?LPCSTR, dwStyle : DWORD, X : c_int, Y : c_int, nWidth : c_int, nHeight : c_int, hWindParent : ?HWND, hMenu : ?HMENU, hInstance : HINSTANCE, lpParam : ?LPVOID) callconv(WINAPI) ?HWND;
extern "user32"   fn ShowWindow(hWnd : HWND, nCmdShow : c_int) callconv(WINAPI) BOOL;

extern "user32"   fn PeekMessageA(lpMsg : *const MSG, hWnd : ?HWND, wMsgFilterMin : UINT, wMsgFilterMax : UINT, wRemoveMsg : UINT) callconv(WINAPI) BOOL;
extern "user32"   fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) BOOL;
extern "user32"   fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) LRESULT;

extern "user32"   fn GetDC(hWnd : ?HWND) callconv(WINAPI) ?HDC;
extern "gdi32"    fn ChoosePixelFormat(hdc : ?HDC, ppfd : *const PIXELFORMATDESCRIPTOR) callconv(WINAPI) c_int;
extern "gdi32"    fn SetPixelFormat(hdc : ?HDC, format : c_int, ppfd : *const PIXELFORMATDESCRIPTOR) callconv(WINAPI) BOOL;

extern "opengl32" fn wglCreateContext(hdc : HDC) callconv(WINAPI) ?HGLRC;
extern "opengl32" fn wglMakeCurrent(hdc : HDC, hglrc : ?HGLRC) callconv(WINAPI) BOOL;
extern "opengl32" fn glGetString(name : c_int) callconv(WINAPI) [*:0] u8;

extern "opengl32" fn glClearColor(r : f32, g : f32, b : f32, a : f32) callconv(WINAPI) void;
extern "opengl32" fn glClear(mask : c_uint) callconv(WINAPI) void;
extern "gdi32"    fn SwapBuffers(hdc : HDC) callconv(WINAPI) BOOL;

extern "user32"   fn PostQuitMessage(i32) callconv(WINAPI) void;
extern "user32"   fn DefWindowProcA(?HWND, UINT, WPARAM, LPARAM) callconv(WINAPI) LRESULT;

// Structs
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

// Modified from wingdi.h
const PIXELFORMATDESCRIPTOR = extern struct {
    nSize           : WORD,
    nVersion        : WORD,
    dwFlags         : DWORD,
    iPixelType      : BYTE,
    cColorBits      : BYTE,
    cRedBits        : BYTE,
    cRedShift       : BYTE,
    cGreenBits      : BYTE,
    cGreenShift     : BYTE,
    cBlueBits       : BYTE,
    cBlueShift      : BYTE,
    cAlphaBits      : BYTE,
    cAlphaShift     : BYTE,
    cAccumBits      : BYTE,
    cAccumRedBits   : BYTE,
    cAccumGreenBits : BYTE,
    cAccumBlueBits  : BYTE,
    cAccumAlphaBits : BYTE,
    cDepthBits      : BYTE,
    cStencilBits    : BYTE,
    cAuxBuffers     : BYTE,
    iLayerType      : BYTE,
    bReserved       : BYTE,
    dwLayerMask     : DWORD,
    dwVisibleMask   : DWORD,
    dwDamageMask    : DWORD,
};

const basic_pfd = PIXELFORMATDESCRIPTOR{
    .nSize           = @sizeOf(PIXELFORMATDESCRIPTOR),
    .nVersion        = 1,
    .dwFlags         = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
    .iPixelType      = PFD_TYPE_RGBA,
    .cColorBits      = 32,
    .cRedBits        = 0,
    .cRedShift       = 0,
    .cGreenBits      = 0,
    .cGreenShift     = 0,
    .cBlueBits       = 0,
    .cBlueShift      = 0,
    .cAlphaBits      = 0,
    .cAlphaShift     = 0,
    .cAccumBits      = 0,
    .cAccumRedBits   = 0,
    .cAccumGreenBits = 0,
    .cAccumBlueBits  = 0,
    .cAccumAlphaBits = 0,
    .cDepthBits      = 24,
    .cStencilBits    = 8,
    .cAuxBuffers     = 0,
    .iLayerType      = PFD_MAIN_PLANE,
    .bReserved       = 0,
    .dwLayerMask     = 0,
    .dwVisibleMask   = 0,
    .dwDamageMask    = 0,
};

// Window procedure.
fn window_procedure(hWnd : ?HWND, message : UINT, wParam : WPARAM, lParam : LPARAM) callconv(.C) LRESULT {
    switch(message) {
        WM_CREATE => {
            init_OpenGL(hWnd);
        },
        WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return DefWindowProcA(hWnd, message, wParam, lParam);
}

fn init_OpenGL(hWnd : ?HWND) void {
    // Set the pixel format to the best approximation to basic_pfd.
    const device_context_handle_result   : ?HDC  = GetDC(hWnd);
    if (device_context_handle_result == null) { wincallerror("Retrieving device context handle failed."); }
    device_context_handle = device_context_handle_result.?;
    
    const best_match_pixel_format : c_int = ChoosePixelFormat(device_context_handle, &basic_pfd);
    if (best_match_pixel_format == 0) { wincallerror("Choosing pixel format failed."); }

    const set_px_format_ok : BOOL = SetPixelFormat(device_context_handle, best_match_pixel_format, &basic_pfd);
    if (set_px_format_ok == FALSE) { wincallerror("Setting pixel format failed."); }

    const opengl_render_context = wglCreateContext(device_context_handle);
    if (opengl_render_context == null) { wincallerror("Creating OpenGL render context failed."); }
    
    const set_gl_render_context_ok = wglMakeCurrent(device_context_handle, opengl_render_context);
    if (set_gl_render_context_ok == FALSE) { wincallerror("Setting OpenGL render context failed."); }
}

// Main procedure. 
pub fn wWinMain(hInstance : w32.HINSTANCE, prevInstance : @TypeOf(null), cmdline : [*:0] u16, showcmd : c_int ) c_int {
    _ = prevInstance;
    _ = cmdline;

    // Start the program stopwatch.
    program_stopwatch = std.time.Timer.start() catch unreachable;
    initial_timestamp = program_stopwatch.read();
    
    const cross_cursor = LoadImageA(null, IDC_CROSS, IMAGE_CURSOR, 0, 0, LR_DEFAULTSIZE | LR_SHARED);
    const brush_color  = CreateSolidBrush(AQUAMARINE_COLOR);

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

    // Adjust the pixel dimensions to factor in the size of the borders.
    _ = AdjustWindowRectEx(&crect, WS_OVERLAPPEDWINDOW, FALSE, WS_EX_TOPMOST);
    
    // Create the window.
    const hWnd = CreateWindowExA(
        WS_EX_TOPMOST,
        "WindowClass1",
        "Blinking Window",
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
        current_timestamp = program_stopwatch.read();
        
        if (peek_result != FALSE) {
            // Handle messages in default way.
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
            if (msg.message == WM_QUIT) { break; }
        } else {
            render_screen();
        }

        peek_result = PeekMessageA(&msg, null, 0, 0, PM_REMOVE);
    }
    
    return @as(c_int, @intCast(msg.wParam));
}

fn render_screen() void {
    // Determine the background color, based on the elapsed program time.
    const program_seconds : f32 = timestamp_delta_to_secs(current_timestamp, initial_timestamp);
    const PULSING_SPEED = 4;
    const gamma = 0.5 * (1 + std.math.sin(PULSING_SPEED * program_seconds));

    const red   = gamma;
    const green = 0;
    const blue  = 0.4 + 0.6 * gamma;

    // Draw the background!
    glClearColor(red, green, blue, 1);
    glClear(GL_COLOR_BUFFER_BIT);

    const swap_ok = SwapBuffers(device_context_handle);
    if (swap_ok == FALSE) {
        std.debug.print("WARNING: SwapBuffers call returned an error.\n", .{}); //@debug
    }
}

fn wincallerror(errorstr : [] const u8) void {
    std.debug.print("ERROR: {s}\n", .{errorstr});
    unreachable;
}

// Note: Zig's standard library timer is monotonic, so by using it we can be sure that t_new - t_old >= 0.  
fn timestamp_delta_to_secs(t_new : u64, t_old : u64) f32 {
    const t_delta = t_new - t_old;
    const t_delta_secs_f64 = @as(f64, @floatFromInt(t_delta)) / @as(f64, @floatFromInt(std.time.ns_per_s));
    return @floatCast(t_delta_secs_f64);
}

// This (and the alias dictionary) are not necessary; but we include them so we
// know what on earth "LPCSTR" and the other type aliases actually are.
fn check_type_eq(t1 : type, t2 : type) void {
    if (t1 != t2) {
        const types_str = std.fmt.comptimePrint("{} / {}", .{t1, t2});
        @compileError("ERROR: Type mismatch:\n    " ++ types_str);
    }
}
