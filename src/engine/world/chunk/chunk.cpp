#include "chunk.h"
#include <gk_types_lib/allocator/allocator.h>
#include "../fat_tree/fat_tree.h"

world::Chunk::Inner::Inner(FatTree& inTree, TreeLayerIndices inPos)
	: _tree(inTree), _treePos(inPos)
{
	auto allocator = gk::globalHeapAllocatorRef();//this->_tree.getAllocatorRef();

	auto res = allocator.mallocBuffer<BlockState>(DEFAULT_BLOCK_STATE_CAPACITY);
	if (res.isError()) {
		std::cout << "Failed to allocate memory for chunk inner" << std::endl;
		exit(-1);
	}

	this->_blockStatesData = res.ok();
}


world::Chunk::Inner::~Inner()
{
	auto allocator = gk::globalHeapAllocatorRef();//this->_tree.getAllocatorRef();

	// TODO also call destructors for block states
	allocator.freeBuffer(this->_blockStatesData, this->_blockStatesCapacity);

	if (this->_breakingProgress != nullptr) {
		this->_breakingProgress->~ArrayList();
	}
}

world::Chunk::Chunk(FatTree& inTree, TreeLayerIndices inPos)
	: _inner(gk::RwLock<Inner>(inTree, inPos))
{}

world::Chunk::~Chunk()
{
	if (this->_inner.tryWrite().none()) {
		std::cout << "Cannot deinit Chunk while other threads have RwLock access to it's inner data" << std::endl;
		exit(-1);
	}
}

gk::LockedReader<world::Chunk::Inner> world::Chunk::read() const
{
	return this->_inner.read();
}

gk::Option<gk::LockedReader<world::Chunk::Inner>> world::Chunk::tryRead() const
{
	return this->_inner.tryRead();
}

gk::LockedWriter<world::Chunk::Inner> world::Chunk::write()
{
	return this->_inner.write();
}

gk::Option<gk::LockedWriter<world::Chunk::Inner>> world::Chunk::tryWrite()
{
	return this->_inner.tryWrite();
}

const world::Chunk::Inner* world::Chunk::unsafeRead() const
{
#if CUBE_DEBUG
	if (this->tryRead().none()) { // What if it randomly fails?
		std::cout << "Chunk current has exclusive access somewhere else. Cannot safely-unsafely read without locking" << std::endl;
		exit(-1);
	}
#endif
	return this->_inner.unsafeGetDataNoLock();
}
