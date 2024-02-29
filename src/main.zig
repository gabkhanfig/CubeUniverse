const c = @import("engine/clibs.zig");

pub fn main() !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        @panic("Failed to initialize glfw!");
    }

    const createWindow = c.glfwCreateWindow(640, 480, "Hello World", null, null);
    if (createWindow == null) {
        c.glfwTerminate();
        @panic("Failed to create glfw window");
    }

    c.glfwMakeContextCurrent(createWindow);

    _ = c.gladLoadGL();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glfwSwapBuffers(createWindow);
    }

    c.glfwTerminate();
}
