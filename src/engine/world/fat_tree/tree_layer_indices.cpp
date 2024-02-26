#include "tree_layer_indices.h"

using namespace world;

#ifdef WITH_TESTS

static_assert(sizeof(TreeLayerIndices) == 12);
static_assert(alignof(TreeLayerIndices) == 4);

comptime_test_case(tree_layer_indices_zero_initialized, {
	const TreeLayerIndices t;
	for (int i = 0; i < TreeLayerIndices::LAYERS; i++) {
		check_eq(t.indexAtLayer(i).value, 0);
	}
});

comptime_test_case(tree_layer_indices_set_indices, {
	TreeLayerIndices t;
	for (int i = 0; i < TreeLayerIndices::LAYERS; i++) {
		t.setIndexAtLayer(i, TreeLayerIndices::Index::init(1, 1, 1));
	}

	for (int i = 0; i < TreeLayerIndices::LAYERS; i++) {
		const TreeLayerIndices::Index ind = t.indexAtLayer(i);
		check_eq(ind.x(), 1);
		check_eq(ind.y(), 1);
		check_eq(ind.z(), 1);
	}
});

#endif