#include "engine.h"
#include <atomic>
#include <chrono>
#include <numeric>
#include <thread>
#include <gk_types_lib/allocator/allocator.h>

using gk::Result;
using gk::ResultOk;
using gk::ResultErr;
using gk::usize;
using gk::u64;
using gk::u32;

std::atomic<Engine*> engineInstance = nullptr;

Result<void, Engine::InitError> Engine::init(const Engine::InitializationParams params, gk::Option<double> timeoutInSeconds)
{
	const auto start = std::chrono::system_clock::now();
	
	const double t = [&]() {
		if (timeoutInSeconds.isSome()) {
			return timeoutInSeconds.some();
		}
		else {
			return 1.0 * 60.0 * 60.0; // 1 hour max
		}
	}();

	while (true) {
		if (engineInstance.load(std::memory_order::acquire) != nullptr) {
			const auto now = std::chrono::system_clock::now();
			const double elapsedTimeMs = std::chrono::duration<double, std::milli>(now - start).count();
			if (elapsedTimeMs > t) {
				return ResultErr<Engine::InitError>(Engine::InitError::timeout);
			}

			std::this_thread::yield();
			continue;
		}

		Engine* expected = nullptr;
		Engine* newEngine = Engine::create(params);
		while (!engineInstance.compare_exchange_weak(expected, newEngine)) {
			std::this_thread::yield();
		}
	}

	Engine* e = engineInstance.load(std::memory_order::acquire);
	check_ne(e, nullptr);

	return gk::ResultOk<void>();
}

void Engine::deinit()
{
	Engine* e = engineInstance.load(std::memory_order::acquire);
	e->_renderThread.~JobThread();
	e->_jobSystem.~JobSystem();
	gk::globalHeapAllocator()->freeObject(e);
	engineInstance.store(nullptr, std::memory_order::release);
}

Engine* Engine::get()
{
	Engine* e = engineInstance.load(std::memory_order::acquire);
	check_ne(e, nullptr);
	return e;
}

//static u32 currentThreadId() {
//	static_assert(sizeof(std::thread::id) == sizeof(u32));
//	const auto threadId = std::this_thread::get_id();
//	return *reinterpret_cast<const u32*>(&threadId);
//}

bool Engine::isCurrentOnRenderThread()
{
	Engine* e = Engine::get();
	check_ne(e, nullptr);
	return e->_renderThread.getThreadId() == std::this_thread::get_id();
}

Engine* Engine::create(const InitializationParams params)
{
	auto res = gk::globalHeapAllocator()->mallocObject<Engine>();
	if (res.isError()) {
		std::cout << "Failed to allocate memory for Engine" << std::endl;
		exit(-1);
	}

	Engine* newEngine = res.ok();
	memset(newEngine, 0, sizeof(Engine));

	new (&newEngine->_renderThread) gk::JobThread();
	new (&newEngine->_jobSystem) gk::JobSystem(params.jobThreadCount);

	return newEngine;
}

Engine::InitializationParams Engine::InitializationParams::defaultParams()
{
	u32 threadCount = 2;
	const u32 logicalThreads = std::thread::hardware_concurrency();
	if (logicalThreads == 0) {
		std::cout << "Failed to get system logical thread count" << std::endl;
		exit(-1);
	}
	else {
		if (logicalThreads < 4) {
			std::cout << "Cube Universe requires a system with 4 or more logical threads" << std::endl;
			exit(-1);
		}
		threadCount = logicalThreads - 2;
	}

	return InitializationParams{ .jobThreadCount = threadCount };
}

#ifdef GK_TYPES_LIB_DEBUG

test_case("Engine Initialization Params Default") {
	const auto defaultParams = Engine::InitializationParams::defaultParams();
	check_ge(defaultParams.jobThreadCount, 4);
}

#endif
