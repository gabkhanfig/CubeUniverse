#include "block_state_indices.h"
#include <iostream>
#include <gk_types_lib/allocator/allocator.h>

// TODO use std::unreachable when it becomes available
[[noreturn]] inline void unreachable() {
#if defined(_MSC_VER) && !defined(__clang__) // MSVC
	__assume(false);
#else // GCC, Clang
	__builtin_unreachable();
#endif
}

u16 world::internal::BlockStateIndicesWidth1::indexAt(const BlockIndex position) const
{
	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize shifted = this->indices[arrayIndex] >> (position.index % 64);

	return static_cast<u16>(shifted & 0b1);
}

void world::internal::BlockStateIndicesWidth1::setIndexAt(const u16 index, const BlockIndex position)
{
	check_le(index, MAX_VALUE);

	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize indexCast = index;
	const usize bitshift = position.index % 64;
	const usize bitmask = indexCast << bitshift;

	this->indices[arrayIndex] = (this->indices[arrayIndex] & ~(0b1ULL << bitshift)) | bitmask;
}

u16 world::internal::BlockStateIndicesWidth2::indexAt(const BlockIndex position) const
{
	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize firstBitIndex = position.index & BIT_INDEX_MASK;
	const usize bitmask = this->indices[arrayIndex] >> (firstBitIndex * BIT_INDEX_MULTIPLIER);

	return static_cast<u16>(bitmask & 0b11);
}

void world::internal::BlockStateIndicesWidth2::setIndexAt(const u16 index, const BlockIndex position)
{
	check_le(index, MAX_VALUE);

	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize firstBitIndex = position.index & BIT_INDEX_MASK;
	const usize indexCast = index;
	const usize bitmaskIndex = indexCast << (firstBitIndex * BIT_INDEX_MULTIPLIER);
	const usize bitmaskExclude = static_cast<usize>(MAX_VALUE) << (firstBitIndex * BIT_INDEX_MULTIPLIER);

	this->indices[arrayIndex] = (this->indices[arrayIndex] & ~bitmaskExclude) | bitmaskIndex;
}

u16 world::internal::BlockStateIndicesWidth4::indexAt(const BlockIndex position) const
{
	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize firstBitIndex = position.index & BIT_INDEX_MASK;
	const usize bitmask = this->indices[arrayIndex] >> (firstBitIndex * BIT_INDEX_MULTIPLIER);

	return static_cast<u16>(bitmask & 0b1111);
}

void world::internal::BlockStateIndicesWidth4::setIndexAt(const u16 index, const BlockIndex position)
{
	check_le(index, MAX_VALUE);

	const usize arrayIndex = position.index % ARRAY_SIZE;
	const usize firstBitIndex = position.index & BIT_INDEX_MASK;
	const usize indexCast = index;
	const usize bitmaskIndex = indexCast << (firstBitIndex * BIT_INDEX_MULTIPLIER);
	const usize bitmaskExclude = static_cast<usize>(MAX_VALUE) << (firstBitIndex * BIT_INDEX_MULTIPLIER);

	this->indices[arrayIndex] = (this->indices[arrayIndex] & ~bitmaskExclude) | bitmaskIndex;
}

u16 world::internal::BlockStateIndicesWidth8::indexAt(const BlockIndex position) const
{
	return this->indices[position.index];
}

void world::internal::BlockStateIndicesWidth8::setIndexAt(const u16 index, const BlockIndex position)
{
	check_le(index, MAX_VALUE);

	this->indices[position.index] = static_cast<u8>(index);
}

u16 world::internal::BlockStateIndicesWidth16::indexAt(const BlockIndex position) const
{
	return this->indices[position.index];
}

void world::internal::BlockStateIndicesWidth16::setIndexAt(const u16 index, const BlockIndex position)
{
	check_lt(index, CHUNK_SIZE); // less than

	this->indices[position.index] = index;
}

world::internal::BlockStateIndices::BlockStateIndices()
{
	auto allocator = gk::globalHeapAllocator();

	const usize bitWidth = static_cast<usize>(IndexBitWidth::b1);
	const void* indices = static_cast<void*>(allocator->mallocObject<BlockStateIndicesWidth1>().ok());
	const usize indicesAsUsize = reinterpret_cast<usize>(indices);

	this->taggedPtr = indicesAsUsize | (bitWidth << ENUM_SHIFT);
}

world::internal::BlockStateIndices::~BlockStateIndices()
{
	auto allocator = gk::globalHeapAllocator();

	const IndexBitWidth tag = this->getTag();
	void* ptr = this->getIndicesPtrMut();

	switch (tag) {
	case IndexBitWidth::b1:
		{
			BlockStateIndicesWidth1* asWidth = static_cast<BlockStateIndicesWidth1*>(ptr);
			allocator->freeObject(asWidth);
		}
		break;

	case IndexBitWidth::b2:
		{
			BlockStateIndicesWidth2* asWidth = static_cast<BlockStateIndicesWidth2*>(ptr);
			allocator->freeObject(asWidth);
		}
		break;

	case IndexBitWidth::b4:
		{
			BlockStateIndicesWidth4* asWidth = static_cast<BlockStateIndicesWidth4*>(ptr);
			allocator->freeObject(asWidth);
		}
		break;

	case IndexBitWidth::b8:
		{
			BlockStateIndicesWidth8* asWidth = static_cast<BlockStateIndicesWidth8*>(ptr);
			allocator->freeObject(asWidth);
		}
		break;

	case IndexBitWidth::b16:
		{
			BlockStateIndicesWidth16* asWidth = static_cast<BlockStateIndicesWidth16*>(ptr);
			allocator->freeObject(asWidth);
		}
		break;

	default:
		unreachable();
	}
}

u16 world::internal::BlockStateIndices::indexAt(const BlockIndex position) const
{
	const IndexBitWidth tag = this->getTag();
	const void* ptr = this->getIndicesPtr();

	switch (tag) {
	case IndexBitWidth::b1:
		{
			const BlockStateIndicesWidth1* asWidth = static_cast<const BlockStateIndicesWidth1*>(ptr);
			return asWidth->indexAt(position);
		}

	case IndexBitWidth::b2:
		{
			const BlockStateIndicesWidth2* asWidth = static_cast<const BlockStateIndicesWidth2*>(ptr);
			return asWidth->indexAt(position);
		}
		
	case IndexBitWidth::b4:
		{
			const BlockStateIndicesWidth4* asWidth = static_cast<const BlockStateIndicesWidth4*>(ptr);
			return asWidth->indexAt(position);
		}
		
	case IndexBitWidth::b8:
		{
			const BlockStateIndicesWidth8* asWidth = static_cast<const BlockStateIndicesWidth8*>(ptr);
			return asWidth->indexAt(position);
		}
		
	case IndexBitWidth::b16:
		{
			const BlockStateIndicesWidth16* asWidth = static_cast<const BlockStateIndicesWidth16*>(ptr);
			return asWidth->indexAt(position);
		}
		
	default:
		unreachable();
	}

	return u16();
}

void world::internal::BlockStateIndices::setIndexAt(const u16 index, const BlockIndex position)
{
	const IndexBitWidth tag = this->getTag();
	void* ptr = this->getIndicesPtrMut();

	switch (tag) {
	case IndexBitWidth::b1:
		{
			check_message(index < 2, "Not enough space reserved to fit `index`, please call BlockStateIndices::reserve()");
			BlockStateIndicesWidth1* asWidth = static_cast<BlockStateIndicesWidth1*>(ptr);
			asWidth->setIndexAt(index, position);
		}	
		break;

	case IndexBitWidth::b2:
		{
			check_message(index < 4, "Not enough space reserved to fit `index`, please call BlockStateIndices::reserve()");
			BlockStateIndicesWidth2* asWidth = static_cast<BlockStateIndicesWidth2*>(ptr);
			asWidth->setIndexAt(index, position);
		}
		break;

	case IndexBitWidth::b4:
		{
			check_message(index < 16, "Not enough space reserved to fit `index`, please call BlockStateIndices::reserve()");
			BlockStateIndicesWidth4* asWidth = static_cast<BlockStateIndicesWidth4*>(ptr);
			asWidth->setIndexAt(index, position);
		}
		break;

	case IndexBitWidth::b8:
		{
			check_message(index < 256, "Not enough space reserved to fit `index`, please call BlockStateIndices::reserve()");
			BlockStateIndicesWidth8* asWidth = static_cast<BlockStateIndicesWidth8*>(ptr);
			asWidth->setIndexAt(index, position);
		}
		break;

	case IndexBitWidth::b16:
		{
			check_message(index < 256, "Not enough space reserved to fit `index`, please call BlockStateIndices::reserve()");
			BlockStateIndicesWidth8* asWidth = static_cast<BlockStateIndicesWidth8*>(ptr);
			asWidth->setIndexAt(index, position);
		}
		break;

	default:
		unreachable();
	}
}

void world::internal::BlockStateIndices::reserve(const u16 uniqueBlockStates)
{
	if (!this->shouldReallocate(uniqueBlockStates)) {
		return;
	}
	this->reallocate(uniqueBlockStates);
}

world::internal::BlockStateIndices::IndexBitWidth world::internal::BlockStateIndices::getTag() const
{
	const usize shift = this->taggedPtr >> ENUM_SHIFT;
	const IndexBitWidth asEnum = static_cast<IndexBitWidth>(shift);
#if CUBE_DEBUG
	switch (asEnum) {
	case IndexBitWidth::b1:
		break;
	case IndexBitWidth::b2:
		break;
	case IndexBitWidth::b4:
		break;
	case IndexBitWidth::b8:
		break;
	case IndexBitWidth::b16:
		break;
	default:
		check_message(false, "Invalid tagged pointer");
	}	
#endif
	return asEnum;
}

const void* world::internal::BlockStateIndices::getIndicesPtr() const
{
	return reinterpret_cast<const void*>(this->taggedPtr & PTR_MASK);
}

void* world::internal::BlockStateIndices::getIndicesPtrMut()
{
	return reinterpret_cast<void*>(this->taggedPtr & PTR_MASK);
}

world::internal::BlockStateIndices::IndexBitWidth world::internal::BlockStateIndices::getRequiredBitWidth(const u16 uniqueBlockStates) const
{
	if (uniqueBlockStates > 256) {
		return IndexBitWidth::b16;
	}
	else if (uniqueBlockStates > 16) {
		return IndexBitWidth::b8;
	}
	else if (uniqueBlockStates > 8) {
		return IndexBitWidth::b4;
	}
	else if (uniqueBlockStates > 4) {
		return IndexBitWidth::b2;
	}
	else {
		return IndexBitWidth::b1;
	}
}

bool world::internal::BlockStateIndices::shouldReallocate(const u16 uniqueBlockStates) const
{
	switch (this->getTag()) {
	case IndexBitWidth::b1: 
		if (uniqueBlockStates > 2) return true;
		break;
	case IndexBitWidth::b2:
		if (uniqueBlockStates > 4) return true;
		break;
	case IndexBitWidth::b4:
		if (uniqueBlockStates > 16) return true;
		break;
	case IndexBitWidth::b8:
		if (uniqueBlockStates > 256) return true;
		break;
	case IndexBitWidth::b16:
		return false;
		break;
	default:
		unreachable();
	}
	return false;
}

void world::internal::BlockStateIndices::reallocate(const u16 uniqueBlockStates)
{
	auto allocator = gk::globalHeapAllocator();

	const IndexBitWidth requiredBitWidth = this->getRequiredBitWidth(uniqueBlockStates);
	const IndexBitWidth oldTag = this->getTag();
	void* oldPtr = this->getIndicesPtrMut();
	
	void* newPtr = [&]() {
		void* p;
		switch (requiredBitWidth) {
			case IndexBitWidth::b1:
				p = allocator->mallocObject<BlockStateIndicesWidth1>().ok();
				new (p) BlockStateIndicesWidth1();
				return p;
			
			case IndexBitWidth::b2:
				p = allocator->mallocObject<BlockStateIndicesWidth2>().ok();
				new (p) BlockStateIndicesWidth2();
				return p;

			case IndexBitWidth::b4:
				p = allocator->mallocObject<BlockStateIndicesWidth4>().ok();
				new (p) BlockStateIndicesWidth4();
				return p;

			case IndexBitWidth::b8:
				p = allocator->mallocObject<BlockStateIndicesWidth8>().ok();
				new (p) BlockStateIndicesWidth8();
				return p;

			case IndexBitWidth::b16:
				p = allocator->mallocObject<BlockStateIndicesWidth16>().ok();
				new (p) BlockStateIndicesWidth16();
				return p;

			default:
				unreachable();
		}
	}();

	{ // Change the taggedPtr of self to then set the indices
		const usize bitWidthAsUsize = static_cast<usize>(requiredBitWidth);
		this->taggedPtr = reinterpret_cast<usize>(newPtr) | (bitWidthAsUsize << ENUM_SHIFT);
	}

	switch (oldTag) {
	case IndexBitWidth::b1:
	{
		BlockStateIndicesWidth1* asWidth = static_cast<BlockStateIndicesWidth1*>(oldPtr);
		for (u16 i = 0; i < CHUNK_SIZE; i++) {
			BlockIndex pos;
			pos.index = i;
			this->setIndexAt(asWidth->indexAt(pos), pos);
		}
		allocator->freeObject(asWidth);
	}
		break;
			
	case IndexBitWidth::b2:
	{
		BlockStateIndicesWidth2* asWidth = static_cast<BlockStateIndicesWidth2*>(oldPtr);
		for (u16 i = 0; i < CHUNK_SIZE; i++) {
			BlockIndex pos;
			pos.index = i;
			this->setIndexAt(asWidth->indexAt(pos), pos);
		}
		allocator->freeObject(asWidth);
	}
		break;

	case IndexBitWidth::b4:
	{
		BlockStateIndicesWidth4* asWidth = static_cast<BlockStateIndicesWidth4*>(oldPtr);
		for (u16 i = 0; i < CHUNK_SIZE; i++) {
			BlockIndex pos;
			pos.index = i;
			this->setIndexAt(asWidth->indexAt(pos), pos);
		}
		allocator->freeObject(asWidth);
	}
		break;

	case IndexBitWidth::b8:
	{
		BlockStateIndicesWidth8* asWidth = static_cast<BlockStateIndicesWidth8*>(oldPtr);
		for (u16 i = 0; i < CHUNK_SIZE; i++) {
			BlockIndex pos;
			pos.index = i;
			this->setIndexAt(asWidth->indexAt(pos), pos);
		}
		allocator->freeObject(asWidth);
	}
		break;

	case IndexBitWidth::b16:
		{
			BlockStateIndicesWidth16* asWidth = static_cast<BlockStateIndicesWidth16*>(oldPtr);
			for (u16 i = 0; i < CHUNK_SIZE; i++) {
				BlockIndex pos;
				pos.index = i;
				this->setIndexAt(asWidth->indexAt(pos), pos);
			}
			allocator->freeObject(asWidth);
		}
		break;

	default:
		unreachable();

	}
}

#if WITH_TESTS

using world::BlockIndex;
using world::CHUNK_LENGTH;
using namespace world::internal;

static_assert(sizeof(BlockStateIndices) == 8);
static_assert(sizeof(BlockStateIndicesWidth1) == 4096);
static_assert(sizeof(BlockStateIndicesWidth2) == 8192);
static_assert(sizeof(BlockStateIndicesWidth4) == 16384);
static_assert(sizeof(BlockStateIndicesWidth8) == 32768);
static_assert(sizeof(BlockStateIndicesWidth16) == 65536);

test_case("block state indices 1 bit") {
	BlockStateIndicesWidth1 indices;

	check_eq(indices.indexAt(BlockIndex(0, 0, 0)), 0);
	check_eq(indices.indexAt(BlockIndex(CHUNK_LENGTH - 1, CHUNK_LENGTH - 1, CHUNK_LENGTH - 1)), 0);
	check_eq(indices.indexAt(BlockIndex(5, 14, 9)), 0);

	indices.setIndexAt(1, BlockIndex(0, 0, 0));
	indices.setIndexAt(1, BlockIndex(CHUNK_LENGTH - 1, CHUNK_LENGTH - 1, CHUNK_LENGTH - 1));
	indices.setIndexAt(1, BlockIndex(5, 14, 9));

	check_eq(indices.indexAt(BlockIndex(0, 0, 0)), 1);
	check_eq(indices.indexAt(BlockIndex(CHUNK_LENGTH - 1, CHUNK_LENGTH - 1, CHUNK_LENGTH - 1)), 1);
	check_eq(indices.indexAt(BlockIndex(5, 14, 9)), 1);

	indices.setIndexAt(0, BlockIndex(0, 0, 0));
	indices.setIndexAt(0, BlockIndex(CHUNK_LENGTH - 1, CHUNK_LENGTH - 1, CHUNK_LENGTH - 1));
	indices.setIndexAt(0, BlockIndex(5, 14, 9));

	check_eq(indices.indexAt(BlockIndex(0, 0, 0)), 0);
	check_eq(indices.indexAt(BlockIndex(CHUNK_LENGTH - 1, CHUNK_LENGTH - 1, CHUNK_LENGTH - 1)), 0);
	check_eq(indices.indexAt(BlockIndex(5, 14, 9)), 0);
}

#endif
