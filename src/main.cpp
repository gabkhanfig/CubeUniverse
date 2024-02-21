extern __declspec(dllimport) void cue_entry(int argc, char** argv);

int main(int argc, char** argv) {
	cue_entry(argc, argv);
}