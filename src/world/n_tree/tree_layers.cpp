#include "tree_layers.h"
#include <gk_types_lib/cpu_features/cpu_feature_detector.h>
#include <gk_types_lib/hash/hashmap.h>
#include <intrin.h>

using world::internal::TreeNodeType;

#pragma intrinsic(_BitScanForward64)

world::internal::NodeTypes::NodeTypes()
	: empty(0)
{}

world::internal::NodeTypes::NodeTypes(NodeTypes&& other) noexcept
{
	empty = other.empty;
}

world::internal::InternalNodes::InternalNodes()
	: types{ TreeNodeType::Empty }
{}


static bool avx512CheckAllNodesEmpty(const TreeNodeType* arr) {
	constexpr u64 equal64Bitmask = ~0;
	constexpr usize iterationCount = world::TREE_NODES_PER_LAYER / 64; // 32 for avx2

	const __m512i* typesVec = reinterpret_cast<const __m512i*>(arr);
	const __m512i enumVec = _mm512_set1_epi8(static_cast<i8>(TreeNodeType::Empty));

	for (usize i = 0; i < iterationCount; i++) {
		const u64 eq = _mm512_cmpeq_epi8_mask(typesVec[i], enumVec);
		if (eq != equal64Bitmask) return false;
	}
	return true;
}

static ArrayList<u16> avx512FindAllChunkIndices(const TreeNodeType* arr) {
	constexpr u64 equal64Bitmask = ~0;
	constexpr u16 iterationCount = world::TREE_NODES_PER_LAYER / 64; // 32 for avx2

	const __m512i* typesVec = reinterpret_cast<const __m512i*>(arr);
	const __m512i enumVec = _mm512_set1_epi8(static_cast<i8>(TreeNodeType::Chunk));

	ArrayList<u16> out;

	for (u16 i = 0; i < iterationCount; i++) {
		u64 eq = _mm512_cmpeq_epi8_mask(typesVec[i], enumVec);
		// none are chunk in batch of 64
		if (eq == 0) { 
			continue;
		}

		// batch of 64 are all chunk
		else if (eq == equal64Bitmask) { 
			for (u16 chunkIndex = 0; chunkIndex < 64; chunkIndex++) {
				out.reserve(64); // will adhere to normal allocation increasing rules, so this is fine.
				// std::vector reserve would be VERY bad here
				out.push(chunkIndex + (i * 64));
			}
			continue;
		}

		// some, but not all, are chunks
		while (true) { 
			gk::Option<usize> opt = gk::internal::bitscanForwardNext(&eq);
			if (opt.none()) break;

			u16 chunkIndex = static_cast<u16>(opt.some());
			out.push(chunkIndex + (i * 64));
		}
	}

	return out;
}

typedef bool(*CheckAllNodesEmptyFunc)(const TreeNodeType*);
typedef ArrayList<u16>(*FindAllChunkIndicesFunc)(const TreeNodeType*);


bool world::internal::InternalNodes::isAllEmpty() const {
	CheckAllNodesEmptyFunc func = []() {
		return avx512CheckAllNodesEmpty;
	}();

	return func(this->types);
}

ArrayList<u16> world::internal::InternalNodes::allChunks() const {
	FindAllChunkIndicesFunc func = []() {
		return avx512FindAllChunkIndices;
	}();

	return func(this->types);
}

world::NTreeLayer::NTreeLayer()
	: parent(nullptr), layer(0), indexInParent(0)
{
}

void world::NTreeLayer::setParent(NTreeLayer* inParent, u16 selfIndexInParent)
{
	check_message(selfIndexInParent < world::TREE_NODES_PER_LAYER, "Cannot exceed number of nodes");
	check_message((inParent->layer + 1) < world::TREE_LAYERS, "Cannot exceed the maximum amount of tree layers");

	parent = inParent;
	layer = parent->layer + 1;
	indexInParent = selfIndexInParent;
}