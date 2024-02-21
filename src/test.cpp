

extern __declspec(dllimport) void cue_runUnitTests(int argc, char** argv);

int main(int argc, char** argv) {
	cue_runUnitTests(argc, argv);
}