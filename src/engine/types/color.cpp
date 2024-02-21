#include "color.h"

#ifdef WITH_TESTS

test_case("TreeNodeColor 0, 0, 0, 0") {
	const auto c = TreeNodeColor::init(0, 0, 0, 0);
	check_eq(c.red(), 0);
	check_eq(c.green(), 0);
	check_eq(c.blue(), 0);
	check_eq(c.alpha(), 0);
}

test_case("TreeNodeColor 7, 7, 7, 7") {
	const auto c = TreeNodeColor::init(7, 7, 7, 7);
	check_eq(c.red(), 7);
	check_eq(c.green(), 7);
	check_eq(c.blue(), 7);
	check_eq(c.alpha(), 7);
}

test_case("TreeNodeColor mixed values") {
	const auto c = TreeNodeColor::init(2, 3, 5, 6);
	check_eq(c.red(), 2);
	check_eq(c.green(), 3);
	check_eq(c.blue(), 5);
	check_eq(c.alpha(), 6);
}

test_case("TreeNodeColor set red component from 0") {
	auto c = TreeNodeColor::init(0, 0, 0, 0);
	c.setRed(7);
	check_eq(c.red(), 7);
	check_eq(c.green(), 0);
	check_eq(c.blue(), 0);
	check_eq(c.alpha(), 0);
}

test_case("TreeNodeColor set red component from 7") {
	auto c = TreeNodeColor::init(7, 7, 7, 7);
	c.setRed(0);
	check_eq(c.red(), 0);
	check_eq(c.green(), 7);
	check_eq(c.blue(), 7);
	check_eq(c.alpha(), 7);
}

test_case("TreeNodeColor set green component from 0") {
	auto c = TreeNodeColor::init(0, 0, 0, 0);
	c.setGreen(7);
	check_eq(c.red(), 0);
	check_eq(c.green(), 7);
	check_eq(c.blue(), 0);
	check_eq(c.alpha(), 0);
}

test_case("TreeNodeColor set green component from 7") {
	auto c = TreeNodeColor::init(7, 7, 7, 7);
	c.setGreen(0);
	check_eq(c.red(), 7);
	check_eq(c.green(), 0);
	check_eq(c.blue(), 7);
	check_eq(c.alpha(), 7);
}

test_case("TreeNodeColor set blue component from 0") {
	auto c = TreeNodeColor::init(0, 0, 0, 0);
	c.setBlue(7);
	check_eq(c.red(), 0);
	check_eq(c.green(), 0);
	check_eq(c.blue(), 7);
	check_eq(c.alpha(), 0);
}

test_case("TreeNodeColor set blue component from 7") {
	auto c = TreeNodeColor::init(7, 7, 7, 7);
	c.setBlue(0);
	check_eq(c.red(), 7);
	check_eq(c.green(), 7);
	check_eq(c.blue(), 0);
	check_eq(c.alpha(), 7);
}

test_case("TreeNodeColor set alpha component from 0") {
	auto c = TreeNodeColor::init(0, 0, 0, 0);
	c.setAlpha(7);
	check_eq(c.red(), 0);
	check_eq(c.green(), 0);
	check_eq(c.blue(), 0);
	check_eq(c.alpha(), 7);
}

test_case("TreeNodeColor set alpha component from 7") {
	auto c = TreeNodeColor::init(7, 7, 7, 7);
	c.setAlpha(0);
	check_eq(c.red(), 7);
	check_eq(c.green(), 7);
	check_eq(c.blue(), 7);
	check_eq(c.alpha(), 0);
}

#endif