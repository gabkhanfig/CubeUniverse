#pragma once

#include "../core.h"
#include <gk_types_lib/string/string.h>

namespace gk {
	struct JobThread;
}

struct GLFWwindow;
struct GLFWmonitor;

namespace graphics {

	struct Window {

		/// Initialize GLFW and create a new window.
		/// Sets the GLFW context thread to be `renderThread`.
		/// @param renderThread: Thread to use for OpenGL
		/// @param windowWidth: Width of the windowed window
		/// @param windowHeight: Height of the windowed window
		/// @param windowName: Title
		/// @return New window
		static Window* init(gk::JobThread* renderThread, int windowWidth, int windowHeight, gk::Str windowName);

		/// This can only be called by the render thread
		void swapBuffers();

		static void pollEvents();

		bool shouldClose() const;

		void terminate();

	private:

		Window(int windowWidth, int windowHeight, gk::Str windowName);

	private:

		gk::String title;

		GLFWwindow* window;

		/// Null for windowed mode
		GLFWmonitor* monitor;

		i32 width;

		i32 height;

	};

} // namespace graphics