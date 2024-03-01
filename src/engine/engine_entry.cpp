#include <iostream>
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include "core.h"
#include "engine.h"

CUBE_API void cue_entry(int argc, char** argv) {
  Engine::init(Engine::InitializationParams::defaultParams(), gk::Option<double>());
  Engine* e = Engine::get();
  e->run();
  Engine::deinit();
}