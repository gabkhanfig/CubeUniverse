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
    const __m256i multiplier = _mm256_set1_epi64x(static_cast<long long>(internal::calculateLayerMultiplier(i)));
    const auto index = indices.indexAtLayer(i);

    const __m256i indicesVec = __m256i{.m256i_i64 = { index.x(), index.y(), index.z(), 0 }};
    const __m256i mult = _mm256_mullo_epi64(multiplier, indicesVec);
    components = _mm256_add_epi64(components, mult);
  }

  components = _mm256_mullo_epi64(components, _mm256_set1_epi64x(CHUNK_LENGTH));
  components = _mm256_sub_epi64(components, _mm256_set1_epi64x(WORLD_MAX_BLOCK_POS + 1));

  return BlockPosition{ .x = components.m256i_i64[0], .y = components.m256i_i64[1], .z = components.m256i_i64[2] };
}

test_case("BlockPosition from tree indices runtime") {
  const auto bpos = BlockPosition::fromTreeIndices(TreeLayerIndices{});
}

test_case("BlockPosition as tree indices runtime") {
  const auto bpos = BlockPosition{.x = 0, .y = 0, .z = 0};
  const auto layers = bpos.asTreeIndices();
  check_eq(layers.indexAtLayer(0).value, TreeLayerIndices::Index::init(2, 2, 2).value);
  for (usize i = 1; i < TreeLayerIndices::LAYERS; i++) {
    check_eq(layers.indexAtLayer(i).value, TreeLayerIndices::Index::init(0, 0, 0).value);
  }
}