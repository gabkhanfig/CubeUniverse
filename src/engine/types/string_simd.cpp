#include <immintrin.h>
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

// const char indicesAvx512[64] = {
//     63, 62, 61, 60, 59, 58, 57, 56, 55, 54, 53, 52, 51, 50, 49, 48, 47, 46, 45, 44, 43, 42, 41, 40, 39, 38, 37, 36, 35, 34, 33, 32,
//     31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
// };

// const char indicesAvx2[32] = {
//     31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
// };

static bool isAvx512Supported() {
	return IsProcessorFeaturePresent(PF_AVX512F_INSTRUCTIONS_AVAILABLE);
}

static bool isAvx2Supported()
{
	return IsProcessorFeaturePresent(PF_AVX2_INSTRUCTIONS_AVAILABLE);
}

static bool avx512CompareEqualStringAndString(const char* buffer, const char* otherBuffer, size_t len) {
    // both are 64 byte aligned
    const size_t equal64Bitmask = ~0;
    const __m512i* thisVec = (const __m512i*)buffer;
    const __m512i* otherVec = (const __m512i*)otherBuffer;

    const size_t remainder = (len + 1) % 64; // add one for null terminator
    const size_t bytesToCheck = remainder ? ((len + 1) + (64 - remainder)) : len + 1;
    for(size_t i = 0; i < bytesToCheck; i += 64) {
        if(_mm512_cmpeq_epi8_mask(*thisVec, *otherVec) != equal64Bitmask) return false;
        thisVec++;
        otherVec++;
    }
    return true;
}

static bool avx2CompareEqualStringAndString(const char* buffer, const char* otherBuffer, size_t len) {
    // both are 32 byte aligned
    const unsigned int equal32Bitmask = ~0;
    const __m256i* thisVec = (const __m256i*)buffer;
    const __m256i* otherVec = (const __m256i*)otherBuffer;

    const size_t remainder = (len + 1) % 32; // add one for null terminator
    const size_t bytesToCheck = remainder ? ((len + 1) + (32 - remainder)) : len + 1;
    for(size_t i = 0; i < bytesToCheck; i += 32) {
        if(_mm256_cmpeq_epi8_mask(*thisVec, *otherVec) != equal32Bitmask) return false;
        thisVec++;
        otherVec++;
    }
    return true;
}

typedef bool (*CmpEqStringAndStringFunc)(const char*, const char*, size_t);

static CmpEqStringAndStringFunc chooseOptimalCmpEqStringAndString() {
    if(isAvx512Supported()) {
        if(true) {
            printf("[String function loader]: Using AVX-512 String-String comparison\n");
        }

        return avx512CompareEqualStringAndString;
    }
    else if(isAvx2Supported()) {
        if(true) {
            printf("[String function loader]: Using AVX-2 String-String comparison\n");
        }

        return avx2CompareEqualStringAndString;
    }
    else {
        printf("[String function loader]: ERROR\nCannot load string comparison functions if AVX-512 or AVX-2 aren't supported\n");
        exit(-1);
    }
}

static bool avx512CompareEqualStringAndSlice(const char* buffer, const char* sliceBuffer, size_t len) {
    const size_t equal64Bitmask = ~0;
    const __m512i* thisVec = (const __m512i*)buffer;
    // https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html#text=_mm512_movm_epi8&ig_expand=1008,306,307,285,4083,5807,4633
    // Maybe faster than _mm512_set1_epi8 ?
    __m512i otherVec; // initializing the memory is unnecessary = _mm512_movm_epi8(0);

    size_t i = 0;
    for(; i <= (len - 64); i += 64) {
		memcpy(&otherVec, sliceBuffer + i, 64);
		if (_mm512_cmpeq_epi8_mask(*thisVec, otherVec) != equal64Bitmask) return false;
		thisVec++;
    }


    for(; i < len; i++) {
        if(buffer[i] != sliceBuffer[i]) return false;
    }
    return true;
}

static bool avx2CompareEqualStringAndSlice(const char* buffer, const char* sliceBuffer, size_t len) {
    const unsigned int equal32Bitmask = ~0;
    const __m256i* thisVec = (const __m256i*)buffer;
    __m256i otherVec; // initializing the memory is unnecessary

    size_t i = 0;
    for(; i <= (len - 32); i += 32) {
		memcpy(&otherVec, sliceBuffer + i, 32);
		if (_mm256_cmpeq_epi8_mask(*thisVec, otherVec) != equal32Bitmask) return false;
		thisVec++;
    }


    for(; i < len; i++) {
        if(buffer[i] != sliceBuffer[i]) return false;
    }
    return true;
}

typedef bool (*CmpEqStringAndSliceFunc)(const char*, const char*, size_t);

static CmpEqStringAndSliceFunc chooseOptimalCmpEqStringAndSlice() {
    if(isAvx512Supported()) {
        if(true) {
            printf("[String function loader]: Using AVX-512 String-Slice comparison\n");
        }

        return avx512CompareEqualStringAndSlice;
    }
    else if(isAvx2Supported()) {
        if(true) {
            printf("[String function loader]: Using AVX-2 String-Slice comparison\n");
        }

        return avx2CompareEqualStringAndSlice;
    }
    else {
        printf("[String function loader]: ERROR\nCannot load string comparison functions if AVX-512 or AVX-2 aren't supported\n");
        exit(-1);
    }
}

static __m256i stringHashIteration(const __m256i* vec, char num) {
	// in the case of SSO, will ignore the 
	const __m256i seed = _mm256_set1_epi64x(0);
	const __m256i indices = _mm256_set_epi8(31, 30, 29, 28, 27, 26, 25, 24, 23, 22, 21, 20, 19, 18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0);
	const __m256i numVec = _mm256_set1_epi8(num);

	// Checks if num is greater than each value of indices.
	// Mask is 0xFF if greater than, and 0x00 otherwise. 
	const __m256i mask = _mm256_cmpgt_epi8(numVec, indices);
	const __m256i partial = _mm256_and_si256(*vec, mask);
	return _mm256_add_epi8(partial, numVec);
}

//! EXTERN FUNCTIONS TO ACCESS IN ZIG
// C++ is used for static variables within functions.

extern "C" bool stringCompareEqualStringAndStringSimdHeapRep(const char* selfBuffer, const char* otherBuffer, size_t len) {
    static CmpEqStringAndStringFunc func = chooseOptimalCmpEqStringAndString();
    return func(selfBuffer, otherBuffer, len);
}

extern "C" bool stringCompareEqualStringAndSliceSimdHeapRep(const char* selfBuffer, const char* otherBuffer, size_t len) {
    static CmpEqStringAndSliceFunc func = chooseOptimalCmpEqStringAndSlice();
    return func(selfBuffer, otherBuffer, len);
}

extern "C" size_t stringComputeHashSimd(const char* selfBuffer, size_t len) {
    constexpr size_t HASH_MODIFIER = 0xc6a4a7935bd1e995ULL;
	constexpr size_t HASH_SHIFT = 47;

    size_t h = 0;

    if (len < 24) { // It's unlikely that a heap string will be small, unless `reserve()` is used, so this is reasonable.
		h = 0 ^ (len * HASH_MODIFIER);
		const __m256i thisVec = _mm256_loadu_epi8((const void*)selfBuffer);
		const __m256i hashIter = stringHashIteration(&thisVec, static_cast<char>(len));
        const size_t* hashPtr = reinterpret_cast<const size_t*>(&hashIter);

		for (size_t i = 0; i < 4; i++) {
			h ^= hashPtr[i];
			h *= HASH_MODIFIER;
			h ^= h >> HASH_SHIFT;
		}
	}
	else {
		h = 0 ^ (len * HASH_MODIFIER);

		const size_t iterationsToDo = ((len) % 32 == 0 ?
			len :
			len + (32 - (len % 32)))
			/ 32;

            
		const __m256i* thisVec = reinterpret_cast<const __m256i*>(selfBuffer);

		for (size_t i = 0; i < iterationsToDo; i++) {
			const char num = i != (iterationsToDo - 1) ? static_cast<char>(32) : static_cast<char>((iterationsToDo * i) - len);
			//check_le(num, 32);
			const __m256i hashIter = stringHashIteration(thisVec + i, num);
            const size_t* hashPtr = reinterpret_cast<const size_t*>(&hashIter);

			for (size_t j = 0; j < 4; j++) {
			    h ^= hashPtr[i];
				h *= HASH_MODIFIER;
				h ^= h >> HASH_SHIFT;
			}
		}
	}

    h ^= h >> HASH_SHIFT;
	h *= HASH_MODIFIER;
	h ^= h >> HASH_SHIFT;
	return h;
}
