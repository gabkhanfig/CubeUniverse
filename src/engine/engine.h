#pragma once

#include <gk_types_lib/error/result.h>
#include <gk_types_lib/option/option.h>
#include <gk_types_lib/job/job_thread.h>
#include <gk_types_lib/job/job_system.h>

namespace graphics {
	struct Window;
	struct OpenGLInstance;
}

/// Manages the entire engine. At any given moment in time, only one engine global may exist,
/// but `Engine.init()` can be called concurrently. This allows concurrently testing varying parts
/// of the engine, as tests will take turns executing, while the others are atomically locked.
/// Afterwards, `Engine.deinit()` must be called, signaling that a new global instance can be set,
/// and that a calling thread can continue executing.
class Engine {
public:

	struct InitializationParams {
		/// Specifies how many threads are to be used by the job system.
		/// It is recommended for this value to be the `system thread count - 2`.
		/// This allows the total used threads by the engine to equal the amount of logical threads
		/// available. This is `jobThreadCount` + `1 main thread` + `1 OpenGL thread`.
		gk::u32 jobThreadCount;


		/// This will query the information of the system at
		/// runtime to determine the optimal default parameters.
		static InitializationParams defaultParams();
	};

	enum class InitError {
		timeout,
	};

	/// Initializes a new engine object, setting the global engine to it, if it hasn't been already.
	/// Call `deinit()` to deinitialize the engine globally.
	/// `timeoutInSeconds` represents the amount of time it will wait for the current global
	/// engine to be deinitialized if it exists. If `timeoutInMillis` it null, it will wait
	/// for 1 hour of real world time.
	/// 
	///  # Errors
	/// 
	/// If the engine has already been globally initialized, the thread will loop for `timeoutInMillis` milliseconds
	/// until `deinit()` is called. If the global instance is not deinitialized before that time, an error is returned.
	/// This behaviour is used to make it straightforward to try different engine configurations concurrently.
	/// 
	/// @param params: How to initialize the engine.
	/// @param timeoutInSeconds: Duration of time to wait to initialize a new global engine.
	/// @return If successful, nothing, otherwise an error.
	static gk::Result<void, InitError> init(const InitializationParams params, gk::Option<double> timeoutInSeconds);

	/// Deinitializes the global engine, freeing it's resources.
	/// Potentially allows the global engine to be initialized again later,
	/// such as in testing.
	static void deinit();

	/// @return The current global engine. Is guaranteed to be non-null.
	static Engine* get();

	/// Checks if the calling thread is the same thread as the OpenGL render thread for the current engine instance.
	/// This is useful because nearly all OpenGL functions require being executed on the same thread
	/// that the OpenGL context was created on, which must be the render thread.
	static bool isCurrentOnRenderThread();

	gk::JobThread& renderThread() { return _renderThread; }

	void run();

private:

	static Engine* create(const InitializationParams params);

	void renderLoop();

private:

	gk::JobThread _renderThread;
	gk::JobSystem _jobSystem;
	graphics::Window* _window;
	graphics::OpenGLInstance* _openglInstance;
};