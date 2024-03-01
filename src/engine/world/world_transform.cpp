#include "world_transform.h"
#include <immintrin.h>
#include <gk_types_lib/cpu_features/cpu_feature_detector.h>

using namespace world;

static_assert(TreeLayerIndices::LAYERS == 15);

static TreeLayerIndices asTreeIndicesAvx512(const BlockPosition& pos) {
  check_le((pos.x + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH, static_cast<i64>(std::numeric_limits<u32>::max()));
  check_le((pos.y + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH, static_cast<i64>(std::numeric_limits<u32>::max()));
  check_le((pos.z + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH, static_cast<i64>(std::numeric_limits<u32>::max()));

  const __m512i xVec = _mm512_set1_epi32((pos.x + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH);
  const __m512i yVec = _mm512_set1_epi32((pos.y + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH);
  const __m512i zVec = _mm512_set1_epi32((pos.z + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH);

  constexpr __m512i layerDivisors = __m512i{ .m512i_u32 = {
    static_cast<u32>(internal::calculateLayerMultiplier(0)),
    static_cast<u32>(internal::calculateLayerMultiplier(1)),
    static_cast<u32>(internal::calculateLayerMultiplier(2)),
    static_cast<u32>(internal::calculateLayerMultiplier(3)),
    static_cast<u32>(internal::calculateLayerMultiplier(4)),
    static_cast<u32>(internal::calculateLayerMultiplier(5)),
    static_cast<u32>(internal::calculateLayerMultiplier(6)),
    static_cast<u32>(internal::calculateLayerMultiplier(7)),
    static_cast<u32>(internal::calculateLayerMultiplier(8)),
    static_cast<u32>(internal::calculateLayerMultiplier(9)),
    static_cast<u32>(internal::calculateLayerMultiplier(10)),
    static_cast<u32>(internal::calculateLayerMultiplier(11)),
    static_cast<u32>(internal::calculateLayerMultiplier(12)),
    static_cast<u32>(internal::calculateLayerMultiplier(13)),
    static_cast<u32>(internal::calculateLayerMultiplier(14)),
    1
  } };

  const __m512i xModuloStep = _mm512_rem_epu32(xVec, layerDivisors);
  const __m512i yModuloStep = _mm512_rem_epu32(yVec, layerDivisors);
  const __m512i zModuloStep = _mm512_rem_epu32(zVec, layerDivisors);

  const __m512i nodeLengthVec = _mm512_set1_epi32(TreeLayerIndices::NODE_LENGTH);

  const __m512i xMultiplyStep = _mm512_mullo_epi32(xModuloStep, nodeLengthVec);
  const __m512i yMultiplyStep = _mm512_mullo_epi32(yModuloStep, nodeLengthVec);
  const __m512i zMultiplyStep = _mm512_mullo_epi32(zModuloStep, nodeLengthVec);

  const __m512i xDivisionStep = _mm512_div_epu32(xMultiplyStep, layerDivisors);
  const __m512i yDivisionStep = _mm512_div_epu32(yMultiplyStep, layerDivisors);
  const __m512i zDivisionStep = _mm512_div_epu32(zMultiplyStep, layerDivisors);

  TreeLayerIndices layers;
  for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
    layers.setIndexAtLayer(i, TreeLayerIndices::Index::init(
      static_cast<u8>(xDivisionStep.m512i_u32[i]),
      static_cast<u8>(yDivisionStep.m512i_u32[i]),
      static_cast<u8>(zDivisionStep.m512i_u32[i])
    ));
  }
  return layers;
}

static TreeLayerIndices asTreeIndicesAvx2(const BlockPosition& pos) {
  // TODO implement avx2.
  // Would it be better to do 2 loops of the same algorithm as the avx512,
  // or would using another algorithm be better?

  const u64 normalizedX = static_cast<u64>(pos.x + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;
  const u64 normalizedY = static_cast<u64>(pos.y + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;
  const u64 normalizedZ = static_cast<u64>(pos.z + WORLD_MAX_BLOCK_POS + 1) / CHUNK_LENGTH;

  TreeLayerIndices indices;
  for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
    indices.setIndexAtLayer(i, internal::calculateLayerIndex(i, normalizedX, normalizedY, normalizedZ));
  }
  return indices;
}


TreeLayerIndices world::BlockPosition::asTreeIndicesRuntime() const
{
  static auto func = []() {
    if (gk::x86::isAvx512Supported()) {
      return asTreeIndicesAvx512;
    }
    else if (gk::x86::isAvx2Supported()) {
      return asTreeIndicesAvx2;
    }
    else {
      std::cout << "Failed to load BlockPosition-TreeIndices conversion function. AVX512 or AVX2 are required!" << std::endl;
      exit(-1);
    }
  }();

  return func(*this);
}

BlockPosition world::BlockPosition::fromTreeIndicesRuntime(const TreeLayerIndices indices)
{ // NOTE this can probably be done similar to the avx512 as tree indices algorithm
  __m256i components = _mm256_set1_epi64x(0);

  for (usize i = 0; i < TreeLayerIndices::LAYERS; i++) {
    const __m256i multiplier = _mm256_set1_epi64x(static_cast<long long>(internal::calculateLayerMultiplier(i)) / TreeLayerIndices::NODE_LENGTH);
    const auto index = indices.indexAtLayer(i);

    const __m256i indicesVec = __m256i{.m256i_i64 = { index.x(), index.y(), index.z(), 0 }};
    const __m256i mult = _mm256_mullo_epi64(multiplier, indicesVec);
    components = _mm256_add_epi64(components, mult);
  }

  components = _mm256_mullo_epi64(components, _mm256_set1_epi64x(CHUNK_LENGTH));
  components = _mm256_sub_epi64(components, _mm256_set1_epi64x(WORLD_MAX_BLOCK_POS + 1));

  return BlockPosition{ .x = components.m256i_i64[0], .y = components.m256i_i64[1], .z = components.m256i_i64[2] };
}

#if WITH_TESTS

static_assert(sizeof(BlockFacing) == 1);
static_assert(alignof(BlockFacing) == 1);
static_assert(sizeof(BlockIndex) == 2);
static_assert(alignof(BlockIndex) == 2);
static_assert(sizeof(BlockPosition) == 24);
static_assert(alignof(BlockPosition) == 8);
static_assert(sizeof(WorldPosition) == 24);
static_assert(alignof(WorldPosition) == 4);

static constexpr void testBlockIndexCompoments() {
  const auto bi = BlockIndex(1, 8, 31);
  check_eq(bi.x(), 1);
  check_eq(bi.y(), 8);
  check_eq(bi.z(), 31);
}

test_case("block index components") { testBlockIndexCompoments(); }
comptime_test_case(block_index_components, { testBlockIndexCompoments(); })

static constexpr void testBlockIndexOnChunkEdge() {
  {
    const auto bi = BlockIndex(0, 0, 0);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(0, 1, 1);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(1, 0, 1);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(1, 1, 0);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(CHUNK_LENGTH - 1, 2, 2);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(2, CHUNK_LENGTH - 1, 2);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(2, 2, CHUNK_LENGTH - 1);
    check(bi.isOnChunkEdge());
  }
  {
    const auto bi = BlockIndex(15, 15, 15);
    check_not(bi.isOnChunkEdge());
  }
}

test_case("block index on chunk edge") { testBlockIndexOnChunkEdge(); }
comptime_test_case(block_index_on_chunk_edge, { testBlockIndexOnChunkEdge(); })

static constexpr void testBlockPositionAsBlockIndex() {
  {
    const BlockPosition pos{};
    const auto bi = pos.asBlockIndex();
    check_eq(bi.x(), 0);
    check_eq(bi.y(), 0);
    check_eq(bi.z(), 0);
  }
  {
    const BlockPosition pos{.x = 1, .y = 1, .z = 1};
    const auto bi = pos.asBlockIndex();
    check_eq(bi.x(), 1);
    check_eq(bi.y(), 1);
    check_eq(bi.z(), 1);
  }
  {
    const BlockPosition pos{.x = -1, .y = -1, .z = -1};
    const auto bi = pos.asBlockIndex();
    check_eq(bi.x(), CHUNK_LENGTH - 1);
    check_eq(bi.y(), CHUNK_LENGTH - 1);
    check_eq(bi.z(), CHUNK_LENGTH - 1);
  }
}

test_case("block position as block index") { testBlockPositionAsBlockIndex(); }
comptime_test_case(block_position_as_block_index, { testBlockPositionAsBlockIndex(); })

static constexpr void testBlockPositionFromTreeLayerIndices() {
  TreeLayerIndices indices; // is 0 initialized
  indices.setIndexAtLayer(0, TreeLayerIndices::Index::init(2, 2, 2));
  {
    const auto bpos = BlockPosition::fromTreeIndices(indices);
    check_eq(bpos.x, 0);
    check_eq(bpos.y, 0);
    check_eq(bpos.z, 0);
  }

  indices.setIndexAtLayer(TreeLayerIndices::LAYERS - 1, TreeLayerIndices::Index::init(1, 1, 1));
  {
    const auto bpos = BlockPosition::fromTreeIndices(indices);
    check_eq(bpos.x, 32);
    check_eq(bpos.y, 32);
    check_eq(bpos.z, 32);
  }
}

test_case("block position from tree layer indices") { testBlockPositionFromTreeLayerIndices(); }
comptime_test_case(block_position_from_tree_layer_indices, { testBlockPositionFromTreeLayerIndices(); })

static constexpr void testBlockPositionAsTreeLayerIndices() {
  {
    const BlockPosition pos{};
    const TreeLayerIndices indices = pos.asTreeIndices();
    check_eq(indices.indexAtLayer(0), TreeLayerIndices::Index::init(2, 2, 2));
    for (usize i = 1; i < TreeLayerIndices::LAYERS; i++) {
      check_eq(indices.indexAtLayer(i), TreeLayerIndices::Index::init(0, 0, 0));
    }
  }
  {
    const BlockPosition pos{.x = 31, .y = 31, .z = 31};
    const TreeLayerIndices indices = pos.asTreeIndices();
    check_eq(indices.indexAtLayer(0), TreeLayerIndices::Index::init(2, 2, 2));
    for (usize i = 1; i < TreeLayerIndices::LAYERS; i++) {
      check_eq(indices.indexAtLayer(i), TreeLayerIndices::Index::init(0, 0, 0));
    }
  }
  { // next chunk over
    const BlockPosition pos{.x = 32, .y = 32, .z = 32};
    const TreeLayerIndices indices = pos.asTreeIndices();
    check_eq(indices.indexAtLayer(0), TreeLayerIndices::Index::init(2, 2, 2));
    for (usize i = 1; i < TreeLayerIndices::LAYERS - 1; i++) {
      check_eq(indices.indexAtLayer(i), TreeLayerIndices::Index::init(0, 0, 0));
    }
    check_eq(indices.indexAtLayer(TreeLayerIndices::LAYERS - 1), TreeLayerIndices::Index::init(1, 1, 1));
  }
  { // double conversion
    const BlockPosition pos{ .x = 123456789, .y = -5000000000, .z = WORLD_MAX_BLOCK_POS };
    const TreeLayerIndices indices = pos.asTreeIndices();
    const BlockPosition convertBack = BlockPosition::fromTreeIndices(indices);

    // clamps to increment of CHUNK_LENGTH
    check_eq((pos.x - (pos.x % CHUNK_LENGTH)), convertBack.x);
    check_eq((pos.y - (pos.y % CHUNK_LENGTH)), convertBack.y);
    check_eq((pos.z - (pos.z % CHUNK_LENGTH)), convertBack.z);
  }
}

test_case("block position as tree layer indices") { testBlockPositionAsTreeLayerIndices(); }
comptime_test_case(block_position_as_tree_layer_indices, { testBlockPositionAsTreeLayerIndices(); })

static constexpr void testBlockPositionAsVector() {
  const BlockPosition pos{ .x = 50, .y = -100, .z = 200 };
  const glm::dvec3 vec = pos.asVector();
  check_eq(vec.x, 50);
  check_eq(vec.y, -100);
  check_eq(vec.z, 200);
}

test_case("block position as vector") { testBlockPositionAsVector(); }
comptime_test_case(block_position_as_vector, { testBlockPositionAsVector(); })

static constexpr void testBlockPositionFromVector() {
  const glm::dvec3 vec(50.5, -100.4, 200.9);
  const BlockPosition pos = BlockPosition::fromVector(vec);
  check_eq(pos.x, 50);
  check_eq(pos.y, -100);
  check_eq(pos.z, 200);
}

test_case("block position from vector") { testBlockPositionFromVector(); }
comptime_test_case(block_position_from_vector, { testBlockPositionFromVector(); })

static constexpr void testBlockPositionEqual() {
  {
    const auto pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    const auto pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    check_eq(pos1, pos2);
  }
  {
    const auto pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS + 1, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    const auto pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    check_ne(pos1, pos2);
  }
  {
    const auto pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = -1, .z = WORLD_MAX_BLOCK_POS };
    const auto pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    check_ne(pos1, pos2);
  }
  {
    const auto pos1 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS - 1 };
    const auto pos2 = BlockPosition{ .x = WORLD_MIN_BLOCK_POS, .y = 0, .z = WORLD_MAX_BLOCK_POS };
    check_ne(pos1, pos2);
  }
}

test_case("block position equal") { testBlockPositionEqual(); }
comptime_test_case(block_position_equal, { testBlockPositionEqual(); })


#endif