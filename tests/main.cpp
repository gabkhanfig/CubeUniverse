#include <gtest/gtest.h>
#include <core/core.h>
#include <game/lib.h>

int main(int argc, char** argv) {
	::testing::InitGoogleTest(&argc, argv);
	RUN_ALL_TESTS();
}

TEST(Something, Something) {
	EXPECT_EQ(1, 1);
}

TEST(Game, Add) {
	EXPECT_EQ(addNumbers(1, 1), 2);
}
