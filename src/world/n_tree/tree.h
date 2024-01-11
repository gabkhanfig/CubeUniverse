#pragma once

#include "tree_index.h"
#include "tree_layers.h"
#include <gk_types_lib/sync/rw_lock.h>

namespace world
{
	/**
	* Like an Octree but instead of 2x2x2, it's 16x16x16
	*/
	struct NTree {
	public:

		NTree();


	private:

		NTree(const NTree&) = delete;
		NTree(NTree&&) = delete;
		NTree& operator = (const NTree&) = delete;
		NTree& operator = (NTree&&) = delete;

	private:
		NTreeLayer topLayer;

	};

} // namespace world