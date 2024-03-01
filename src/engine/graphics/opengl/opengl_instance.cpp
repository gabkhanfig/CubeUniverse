#include "opengl_instance.h"
#include <gk_types_lib/job/job_thread.h>
#include <glad/glad.h>

graphics::OpenGLInstance* graphics::OpenGLInstance::init(gk::JobThread* renderThread)
{
	auto future = renderThread->runJob(gladLoadGL);
	int result = future.wait();
	if (result == GL_FALSE) {
		std::cout << "Failed to load OpenGL" << std::endl;
		exit(EXIT_FAILURE);
	}
	
	return new OpenGLInstance();
}

void graphics::OpenGLInstance::clear()
{
	glClear(GL_COLOR_BUFFER_BIT);
}
