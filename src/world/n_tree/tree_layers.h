#pragma once 

#include "tree_index.h"
#include <gk_types_lib/sync/rw_lock.h>
#include <engine/types/color.h>

namespace world
{
	struct NTreeLayer;
	struct Chunk;

	namespace internal
	{
		/**
		* Corresponds to world::NodeTypes union to make them as tagged union,
		* but with the advantage of SOA for SIMD operations on the tags.
		*/
		enum class TreeNodeType : i8 {
			/**
			*/
			Empty = 0,

			/**
			*/
			ChildNode = 1,

			/**
			*/
			Colored = 2,

			/**
			*/
			LightEmitting = 3,

			/**
			*/
			Chunk = 4
		};

		/**
		*/
		union NodeTypes {
			u64 empty;
			NTreeLayer* childNode;
			Color colored;
			u64 lightEmittingPlaceholder;
			Chunk* chunk;

			NodeTypes();

			NodeTypes(NodeTypes&& other) noexcept;

			NodeTypes(const NodeTypes&) = delete;
			NodeTypes& operator = (const NodeTypes&) = delete;
			NodeTypes& operator = (NodeTypes&&) = delete;
		};

		/**
		*/
		struct alignas(64) InternalNodes {
			TreeNodeType types[TREE_NODES_PER_LAYER];
			NodeTypes elements[TREE_NODES_PER_LAYER];

			InternalNodes();

			InternalNodes(const InternalNodes&) = delete;
			InternalNodes(InternalNodes&&) = delete;
			InternalNodes& operator = (const InternalNodes&) = delete;
			InternalNodes& operator = (InternalNodes&&) = delete;

			/**
			*/
			bool isAllEmpty() const;

			/**
			* Fetch the indices of all of the nodes that are chunks using AVX-512 or AVX-2.
			* If the ArrayList returned is length 0, none of the nodes are chunks.
			* 
			* @return The indices of the chunk nodes.
			*/
			ArrayList<u16> allChunks() const;


		};
	}

	struct NTreeLayer {
	private:
		using TreeNodeType = internal::TreeNodeType;
		using NodeTypes = internal::NodeTypes;
		using InternalNodes = internal::InternalNodes;



	public:

		NTreeLayer();

		/**
		*/
		void setParent(NTreeLayer* inParent, u16 selfIndexInParent);

	private:

		NTreeLayer(const NTreeLayer&) = delete;
		NTreeLayer(NTreeLayer&&) = delete;
		NTreeLayer& operator = (const NTreeLayer&) = delete;
		NTreeLayer& operator = (NTreeLayer&&) = delete;

	private:

		NTreeLayer* parent;
		u8 layer;
		u16 indexInParent;
		gk::RwLock<InternalNodes> nodes;
	};

} // namespace world