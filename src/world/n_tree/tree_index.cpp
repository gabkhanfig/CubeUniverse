#if CUBE_UNIVERSE_TEST

#include "tree_index.h"

using TreeDepthIndices = world::TreeDepthIndices;

test_case("TreeDepthIndices Default Construct") {
	TreeDepthIndices ind;
	check_eq(ind.indexAtLayer(0), 0);
	check_eq(ind.indexAtLayer(1), 0);
	check_eq(ind.indexAtLayer(2), 0);
	check_eq(ind.indexAtLayer(3), 0);
	check_eq(ind.indexAtLayer(4), 0);
	check_eq(ind.indexAtLayer(5), 0);
	check_eq(ind.indexAtLayer(6), 0);
}

test_case("TreeDepthIndices Set Indices Length 1") {
	u16 indices[] = { 56 };
	TreeDepthIndices ind;
	ind.setIndices(indices, 1);

	check_eq(ind.indexAtLayer(0), 56);
}

test_case("TreeDepthIndices Set Indices Not Max Length") {
	u16 indices[] = { 55, 56, 57, 58, 59 };
	TreeDepthIndices ind;
	ind.setIndices(indices, 5);

	for (u16 i = 0; i < 5; i++) {
		const u16 nodeIndex = 55 + i;
		check_eq(ind.indexAtLayer(i), nodeIndex);
	}
}

test_case("TreeDepthIndices Set Indices Max Length") {
	u16 indices[] = { 55, 56, 57, 58, 59, 60, 61 };
	TreeDepthIndices ind;
	ind.setIndices(indices, world::TREE_LAYERS);

	for (u16 i = 0; i < world::TREE_LAYERS; i++) {
		const u16 nodeIndex = 55 + i;
		check_eq(ind.indexAtLayer(i), nodeIndex);
	}
}

test_case("TreeDepthIndices Set Index At Layer") {
	TreeDepthIndices ind;
	ind.setIndexAtLayer(500, 2);
	ind.setIndexAtLayer(250, 4);

	check_eq(ind.indexAtLayer(2), 500);
	check_eq(ind.indexAtLayer(4), 250);
}

#endif