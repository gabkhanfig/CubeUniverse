#include "window.h"
#include <GLFW/glfw3.h>
#include <gk_types_lib/job/job_thread.h>
#include "../engine.h"

graphics::Window* graphics::Window::init(gk::JobThread* renderThread, int windowWidth, int windowHeight, gk::Str windowName)
{
	/* Initialize the library */
	if (glfwInit() == GLFW_FALSE) {
		std::cout << "Failed to initialize GLFW" << std::endl;
		abort();
	}
	
	Window* w = new Window(windowWidth, windowHeight, windowName);
	auto future = renderThread->runJob(glfwMakeContextCurrent, (GLFWwindow*)w->window);
	future.wait();
	return w;
}

void graphics::Window::swapBuffers()
{
	check(Engine::isCurrentOnRenderThread());
	glfwSwapBuffers(this->window);
}

void graphics::Window::pollEvents()
{
	glfwPollEvents();
}

bool graphics::Window::shouldClose() const
{
	return glfwWindowShouldClose(this->window);
}

void graphics::Window::terminate()
{
	glfwTerminate();
}

graphics::Window::Window(int windowWidth, int windowHeight, gk::Str windowName)
	: width(windowWidth), height(windowHeight), title(windowName), monitor(nullptr), window(nullptr)
{
	this->monitor = nullptr;
	this->window = glfwCreateWindow(640, 480, "Hello World", this->monitor, NULL);
	if (this->window == nullptr) {
		std::cout << "Failed to create GLFW window" << std::endl;
		glfwTerminate();
		abort();
	}
}
