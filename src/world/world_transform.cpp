#include "world_transform.h"

#if CUBE_UNIVERSE_TEST

using BlockFacing = world::BlockFacing;
using BlockPos = world::BlockPos;
using WorldPos = world::WorldPos; 
using TreeDepthIndices = world::TreeDepthIndices;

comptime_test_case(BlockFacing, DefaultConstruct, {
	BlockFacing face;
	check_not(face.isFacing(BlockFacing::Down));
	check_not(face.isFacing(BlockFacing::North));
	check_not(face.isFacing(BlockFacing::East));
	check_not(face.isFacing(BlockFacing::South));
	check_not(face.isFacing(BlockFacing::West));
	check_not(face.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, ConstructWithSingularDirection, {
	BlockFacing face = BlockFacing::Down;
	check(face.isFacing(BlockFacing::Down));
	check_not(face.isFacing(BlockFacing::North));
	check_not(face.isFacing(BlockFacing::East));
	check_not(face.isFacing(BlockFacing::South));
	check_not(face.isFacing(BlockFacing::West));
	check_not(face.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, ConstructWithMultipleDirections, {
	BlockFacing face = BlockFacing::North | BlockFacing::West;
	check_not(face.isFacing(BlockFacing::Down));
	check(face.isFacing(BlockFacing::North));
	check_not(face.isFacing(BlockFacing::East));
	check_not(face.isFacing(BlockFacing::South));
	check(face.isFacing(BlockFacing::West));
	check_not(face.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, AssignWithSingularDirection, {
	BlockFacing face = BlockFacing::Up;
	face = BlockFacing::Down;
	check(face.isFacing(BlockFacing::Down));
	check_not(face.isFacing(BlockFacing::North));
	check_not(face.isFacing(BlockFacing::East));
	check_not(face.isFacing(BlockFacing::South));
	check_not(face.isFacing(BlockFacing::West));
	check_not(face.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, AssignWithMultipleDirections, {
	BlockFacing face = BlockFacing::South | BlockFacing::Up | BlockFacing::East;
	face = BlockFacing::North | BlockFacing::West;
	check_not(face.isFacing(BlockFacing::Down));
	check(face.isFacing(BlockFacing::North));
	check_not(face.isFacing(BlockFacing::East));
	check_not(face.isFacing(BlockFacing::South));
	check(face.isFacing(BlockFacing::West));
	check_not(face.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfNone, {
	BlockFacing face;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionDown, {
	BlockFacing face = BlockFacing::Down;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionNorth, {
	BlockFacing face = BlockFacing::North;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionEast, {
	BlockFacing face = BlockFacing::East;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionSouth, {
	BlockFacing face = BlockFacing::South;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionWest, {
	BlockFacing face = BlockFacing::West;
	BlockFacing opposite = face.opposite();
	check_not(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfOneDirectionUp, {
	BlockFacing face = BlockFacing::Up;
	BlockFacing opposite = face.opposite();
	check(opposite.isFacing(BlockFacing::Down));
	check_not(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
	});

comptime_test_case(BlockFacing, OppositeOfMultipleDirections, {
	BlockFacing face = BlockFacing::South | BlockFacing::Up | BlockFacing::East;
	BlockFacing opposite = face.opposite();
	check(opposite.isFacing(BlockFacing::Down));
	check(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check(opposite.isFacing(BlockFacing::West));
	check_not(opposite.isFacing(BlockFacing::Up));
});

comptime_test_case(BlockFacing, OppositeOfMultipleDirectionsWithOverlap, {
	BlockFacing face = BlockFacing::South | BlockFacing::Up | BlockFacing::Down;
	BlockFacing opposite = face.opposite();
	check(opposite.isFacing(BlockFacing::Down));
	check(opposite.isFacing(BlockFacing::North));
	check_not(opposite.isFacing(BlockFacing::East));
	check_not(opposite.isFacing(BlockFacing::South));
	check_not(opposite.isFacing(BlockFacing::West));
	check(opposite.isFacing(BlockFacing::Up));
});

#endif