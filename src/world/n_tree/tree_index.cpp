#include "tree_index.h"

u8 world::TreeDepthIndices::len() const
{
	const usize shifted = this->value >> 60;
	return static_cast<u8>(shifted);
}

gk::Option<u16> world::TreeDepthIndices::indexAtDepth(u8 depth) const
{
	check_message(depth < TREE_LAYERS, "depth must be less than world::TREE_LAYERS");
	if (depth >= len()) {
		return gk::Option<u16>();
	}
	constexpr usize bitmask = 0b111111111111; // 4096 different values -> 16 x 16 x 16
	const usize bitShift = depth * 12;
	const u16 index = (this->value >> bitShift) & bitmask;
	return gk::Option<u16>(index);
}

void world::TreeDepthIndices::setIndices(const u16* nodeIndices, usize count)
{
	check_message(count <= TREE_LAYERS, "count must be less than or equal to world::TREE_LAYERS");
	usize newValue = 0;
	for (u8 i = 0; i < count; i++) {
		check_message(nodeIndices[i] < TREE_NODES_PER_LAYER, "Tree Index cannot exceed world::TREE_NODES_PER_LAYER");
		const usize bitShift = i * 12;
		newValue |= static_cast<usize>(nodeIndices[i]) << bitShift;
	}
	newValue |= count << 60;
	this->value = newValue;
}

void world::TreeDepthIndices::unsafeSetDepth(u8 newDepth)
{
	check_message(newDepth <= TREE_LAYERS, "depth must be less than world::TREE_LAYERS");

	constexpr usize mask = ~(0b1111ULL << 60);
	this->value = (this->value & mask) | (static_cast<usize>(newDepth) << 60);
}

void world::TreeDepthIndices::unsafeSetIndexAtDepth(u16 nodeIndex, u8 depth)
{
	check_message(depth <= TREE_LAYERS, "depth must be less than world::TREE_LAYERS");
	check_message(depth > 0, "depth must be greater than 0");
	check_message(nodeIndex < TREE_NODES_PER_LAYER, "Tree Index cannot exceed world::TREE_NODES_PER_LAYER");

	const usize bitShift = depth * 12;
	const usize mask = ~(0b111111111111ULL << bitShift);

	this->value = (this->value & mask) | (static_cast<usize>(nodeIndex) << bitShift);
}


#if GK_TYPES_LIB_TEST

using TreeDepthIndices = world::TreeDepthIndices;

test_case("TreeDepthIndices Default Construct") {
	TreeDepthIndices ind;
	check_eq(ind.len(), 0);
}

test_case("TreeDepthIndices Set Indices Length 1") {
	u16 indices[] = { 56 };
	TreeDepthIndices ind;
	ind.setIndices(indices, 1);

	check_eq(ind.len(), 1);
	check(ind.indexAtDepth(0).isSome());
	check_eq(ind.indexAtDepth(0).some(), 56);
}

test_case("TreeDepthIndices Set Indices Max Length") {
	u16 indices[] = { 55, 56, 57, 58, 59 };
	TreeDepthIndices ind;
	ind.setIndices(indices, 5);

	check_eq(ind.len(), 5);
	for (u16 i = 0; i < 5; i++) {
		const u16 nodeIndex = 55 + i;
		check(ind.indexAtDepth(i).isSome());
		check_eq(ind.indexAtDepth(i).some(), nodeIndex);
	}
}

test_case("TreeDepthIndices Unsafe Set Depth") {
	TreeDepthIndices ind;
	ind.unsafeSetDepth(3);
	check_eq(ind.len(), 3);
}

test_case("TreeDepthIndices Unsafe Set Index At Depth") {
	TreeDepthIndices ind;
	ind.unsafeSetDepth(4);
	ind.unsafeSetIndexAtDepth(1234, 3);
	check(ind.indexAtDepth(3).isSome());
	check_eq(ind.indexAtDepth(3).some(), 1234);
}

#endif