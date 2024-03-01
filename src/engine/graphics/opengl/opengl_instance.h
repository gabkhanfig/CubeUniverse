#pragma once

#include "../../core.h"

namespace gk {
	struct JobThread;
}

namespace graphics {

	struct OpenGLInstance {

		static OpenGLInstance* init(gk::JobThread* renderThread);

		void clear();

	private:
	};

}