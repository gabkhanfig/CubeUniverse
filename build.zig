//! https://github.com/spanzeri/vkguide-zig/blob/main/build.zig
// c:\Users\Admin\AppData\Roaming\Code\User\globalStorage\ziglang.vscode-zig\zig_install\zig.exe
const std = @import("std");
const LazyPath = std.Build.LazyPath;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const engine_shared_lib = b.addSharedLibrary(.{
        .name = "CubeUniverseEngine",
        .root_source_file = .{ .path = "src/engine/engine.zig" },
        .target = target,
        .optimize = optimize,
    });

    linkAndIncludeCLibs(target, b, engine_shared_lib);
    if (target.result.os.tag == .windows) {
        b.installBinFile("thirdparty/LuaJIT/src/lua51.dll", "lua51.dll");
        b.installBinFile("zig-out/lib/CubeUniverseEngine.dll", "CubeUniverseEngine.dll");
    }
    b.installArtifact(engine_shared_lib);

    const exe = b.addExecutable(.{
        .name = "CubeUniverse",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibrary(engine_shared_lib);

    //linkAndIncludeCLibs(target, b, exe);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const engine_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/engine/engine_unit_tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    // TODO determine optimal way to link c libraries. Maybe link against the engine dll, or something else?
    const engine_system_tests = b.addExecutable(.{
        .name = "CubeUniverseSystemTests",
        .root_source_file = .{ .path = "src/engine/engine_system_tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    // NOTE Unit tests are unable to link to the DLL. Likely a bug?
    //exe_unit_tests.linkLibrary(engine_shared_lib);

    const run_engine_unit_tests = b.addRunArtifact(engine_unit_tests);
    const run_engine_system_tests = b.addRunArtifact(engine_system_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_engine_unit_tests.step);
    test_step.dependOn(&run_engine_system_tests.step);
}

fn linkAndIncludeCLibs(target: std.Build.ResolvedTarget, b: *std.Build, artifact: *std.Build.Step.Compile) void {
    artifact.linkLibC();
    artifact.linkLibCpp();

    // Add Vulkan dependency
    // The vulkan sdk is required to be installed, along with the VK_SDK_PATH environment variable to be set
    //const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan"; // works in nighty 1200 and later
    const vk_lib_name = "vulkan-1";
    artifact.linkSystemLibrary(vk_lib_name);
    if (b.env_map.get("VK_SDK_PATH")) |path| {
        artifact.addLibraryPath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/lib", .{path}) catch @panic("Out of Memory") });
        artifact.addIncludePath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/include", .{path}) catch @panic("Out of Memory") });
    }
    // to add a module, do this
    //exe.root_module.addImport("module name", module);

    artifact.addLibraryPath(LazyPath.relative("thirdparty/glfw-zig/zig-out/lib"));
    artifact.addIncludePath(LazyPath.relative("thirdparty/glfw-zig/zig-out/include"));
    artifact.addObjectFile(LazyPath.relative("thirdparty/glfw-zig/zig-out/lib/glfw.lib"));

    // see thirdparty/glfw-zig/build.zig
    artifact.linkSystemLibrary("gdi32");
    artifact.linkSystemLibrary("user32");
    artifact.linkSystemLibrary("shell32");

    const flags = [_][]const u8{};

    // vma
    artifact.addIncludePath(LazyPath.relative("thirdparty/vma"));
    artifact.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/vma/vk_mem_alloc.cpp"), .flags = &flags });

    // stb_image
    artifact.addIncludePath(LazyPath.relative("thirdparty/stb"));
    artifact.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/stb/stb_image.c"), .flags = &flags });

    // LuaJIT
    // https://andrewkelley.me/post/zig-cc-powerful-drop-in-replacement-gcc-clang.html
    artifact.addLibraryPath(LazyPath.relative("thirdparty/LuaJIT/src/"));
    artifact.addIncludePath(LazyPath.relative("thirdparty/LuaJIT/src/"));
    if (target.result.os.tag == .windows) {
        artifact.addObjectFile(LazyPath.relative("thirdparty/LuaJIT/src/libluajit-5.1.dll.a"));
        //b.installBinFile("thirdparty/LuaJIT/src/lua51.dll", "lua51.dll");
    } else {}

    // TODO add glfw backend
    // imgui
    // https://github.com/dearimgui/dear_bindings?tab=readme-ov-file
    //const imgui = b.addModule("imgui", .{ .root_source_file = LazyPath.relative("thirdparty/imgui/zig_imgui.zig") });

    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui_demo.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui_draw.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui_tables.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui_widgets.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/backends/imgui_impl_sdlrenderer2.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/backends/imgui_impl_vulkan.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/imgui.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/cimgui.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/backends/cimgui_impl_sdlrenderer2.cpp"), .flags = &flags });
    // exe.addCSourceFile(.{ .file = LazyPath.relative("thirdparty/imgui/backends/cimgui_impl_vulkan.cpp"), .flags = &flags });

    // exe.addIncludePath(LazyPath.relative("thirdparty/imgui"));
}
