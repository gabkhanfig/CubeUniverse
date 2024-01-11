#include "chunk.h"

world::ChunkInner::ChunkInner(TreeDepthIndices inTreePos)
	: _treePos(inTreePos), _blockStateIds{0}
{
	// Make index 0 valid, for air.
	// If a chunk is ONLY air, it will get deleted when appropriate and turned into an empty node.
	_blockStates.push(nullptr);


}
