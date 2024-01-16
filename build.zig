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

    const exe = b.addExecutable(.{
        .name = "CubeUniverse",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // const src_module = b.addModule("src", .{
    //     .source_file = .{ .path = "src/root.zig" },
    // });
    // exe.addModule("src", src_module);

    // Add Vulkan dependency
    // The vulkan sdk is required to be installed, along with the VK_SDK_PATH environment variable to be set
    //const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan"; // works in nighty 1200 and later
    const vk_lib_name = "vulkan-1";
    exe.linkSystemLibrary(vk_lib_name);
    if (b.env_map.get("VK_SDK_PATH")) |path| {
        exe.addLibraryPath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/lib", .{path}) catch @panic("Out of Memory") });
        exe.addIncludePath(.{ .cwd_relative = std.fmt.allocPrint(b.allocator, "{s}/include", .{path}) catch @panic("Out of Memory") });
    }
    // to add a module, do this
    //exe.root_module.addImport("module name", module);

    exe.addLibraryPath(LazyPath.relative("thirdparty/glfw-zig/zig-out/lib"));
    exe.addIncludePath(LazyPath.relative("thirdparty/glfw-zig/zig-out/include"));
    exe.addObjectFile(LazyPath.relative("thirdparty/glfw-zig/zig-out/lib/glfw.lib"));

    // see thirdparty/glfw-zig/build.zig
    exe.linkSystemLibrary("gdi32");
    exe.linkSystemLibrary("user32");
    exe.linkSystemLibrary("shell32");

    exe.linkLibC();
    exe.linkLibCpp();

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

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    //exe_unit_tests.addModule("src", src_module);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
