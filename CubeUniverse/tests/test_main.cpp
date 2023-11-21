#include <gtest/gtest.h>

#include <cube_core/core.h>

int main(int argc, char** argv) {
	::testing::InitGoogleTest(&argc, argv);
	RUN_ALL_TESTS();
}

TEST(Something, Something) {
	EXPECT_EQ(1, 1);
}

TEST(Game, Add) {

}
