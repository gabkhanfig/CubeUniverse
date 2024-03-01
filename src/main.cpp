//extern __declspec(dllimport) void cue_entry(int argc, char** argv);

#include "engine/engine.h"

int main(int argc, char** argv) {
  Engine::init(Engine::InitializationParams::defaultParams(), gk::Option<double>());
  Engine* e = Engine::get();
  e->run();
  Engine::deinit();
}