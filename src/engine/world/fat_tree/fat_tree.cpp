#include "fat_tree.h"
#include "../chunk/chunk.h"

void world::FatTreeNode::deinit()
{ // TODO add TreeModifyGuard
	switch (this->nodeType()) {
	case Type::empty:
		return;
	case Type::childLayer:

		return;
	case Type::noodleLayer:

		return;

	case Type::chunk:

		return;

	}
}

world::FatTreeNode::Type world::FatTreeNode::nodeType() const
{
	const Type enumTag = static_cast<Type>(this->value & TYPE_MASK);
#if CUBE_DEBUG
	switch (enumTag) {
	case Type::empty:
		break;
	case Type::childLayer:
		break;
	case Type::noodleLayer:
		break;
	case Type::chunk:
		break;
	default:
		std::cout << "invalid FatTreeNode enum tag" << std::endl;
		exit(-1);
	}
#endif
	return enumTag;
}

world::FatTreeLayer& world::FatTreeNode::childLayer()
{
	check_eq(this->nodeType(), Type::childLayer);
	usize ptr = this->value & PTR_MASK;
	return *reinterpret_cast<FatTreeLayer*>(ptr);
}

const world::FatTreeLayer& world::FatTreeNode::childLayer() const
{
	check_eq(this->nodeType(), Type::childLayer);
	usize ptr = this->value & PTR_MASK;
	return *reinterpret_cast<const FatTreeLayer*>(ptr);
}

world::Chunk& world::FatTreeNode::chunk() const
{
	check_eq(this->nodeType(), Type::chunk);
	usize ptr = this->value & PTR_MASK;
	return *reinterpret_cast<Chunk*>(ptr);
}

world::FatTreeNoodle& world::FatTreeNode::noodleLayer()
{
	check_eq(this->nodeType(), Type::noodleLayer);
	usize ptr = this->value & PTR_MASK;
	return *reinterpret_cast<FatTreeNoodle*>(ptr);
}

const world::FatTreeNoodle& world::FatTreeNode::noodleLayer() const
{
	check_eq(this->nodeType(), Type::noodleLayer);
	const usize ptr = this->value & PTR_MASK;
	return *reinterpret_cast<const FatTreeNoodle*>(ptr);
}

world::FatTree::Inner::~Inner()
{
	// something idk
}

gk::Option<world::Chunk&> world::FatTree::Inner::chunkAt(const TreeLayerIndices position) const
{
	auto c = this->chunks.find(position);
	if (c.none()) {
		return gk::Option<Chunk&>();
	}
	Chunk* chunk = *c.some();
	return gk::Option<Chunk&>(*chunk);
}


#if WITH_TESTS

using namespace world;

//static_assert(sizeof(FatTreeNoodle::NoodleJump) == 16);

#endif

world::FatTree::ChunkModifyGuard world::FatTree::lockChunkModify() const
{
	return this->inner.read();
}

gk::Option<world::FatTree::ChunkModifyGuard> world::FatTree::tryLockChunkModify() const
{
	return this->inner.tryRead();
}

world::FatTree::TreeModifyGuard world::FatTree::lockTreeModify()
{
	return this->inner.write();
}

gk::Option<world::FatTree::TreeModifyGuard> world::FatTree::tryLockTreeModify()
{
	return this->inner.tryWrite();
}
