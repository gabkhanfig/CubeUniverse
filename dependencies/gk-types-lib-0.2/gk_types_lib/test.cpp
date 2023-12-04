//#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#define DOCTEST_CONFIG_IMPLEMENT
#include "doctest/doctest_proxy.h"

#include <type_traits>
#include <source_location>
#include "string/string.h"
#include "array/array_list.h"

#include "reflection/struct_name.h"

#include <array>
#include <iostream>
#include <memory>
#include <source_location>
#include <string>
#include <type_traits>
#include "reflection/has_n_fields.h"
#include "reflection/field_name.h"




template <class T>
extern T fake_object;

template <class T>
struct Wrapper {
	using Type = T;
	T v;
};

template <class T>
Wrapper(T) -> Wrapper<T>;

// This workaround is necessary for clang.
template <class T>
constexpr auto wrap(const T& arg) noexcept {
	return Wrapper{ arg };
}

struct Example {
	int ahskdjhaskjdhalskjdaaaa;
};


//template<typename T>
//auto getFieldNames() {
//	// https://en.cppreference.com/w/cpp/language/structured_binding
//	constexpr auto& [f1] = fake_object<T>;
//
//	return gk::getFieldName<f1>();
//	
//
//}


consteval size_t test() {
	gk::String balls = "ahskdjhaskjdhalskjdaaaaaaaaa>(void)"_str;
	gk::String other = balls.substring(0, 23);
	return other.usedBytes();
}

constinit size_t scrotum = test();

int main(int argc, char** argv) {
	using gk::usize;
	doctest::Context context;
	context.applyCommandLine(argc, argv);
	context.setOption("no-breaks", true);
	int res = context.run();

	//constexpr const char* balls = std::source_location::current().function_name();
	////"get_struct_name_impl<struct"
	//std::cout << gk::getStructName<Example*>() << std::endl;
	//std::cout << gk::getStructName<gk::ArrayList<int>*>() << std::endl;

 // constexpr gk::String structName = gk::getStructName<Example>();

	//gk::String balls = "ahskdjhaskjdhalskjdaaaa>(void)"_str;
	//gk::String other = balls.substring(0, 23);
	//std::cout << other << '\n';
	//std::cout << scrotum << '\n';
//	gk::Str initialStr = "struct gk::String __cdecl gk::internal::getNameMsvc<struct Example,&gk::internal::fake_object<struct Example>->ahskdjhaskjdhalskjdaaaa>(void)"_str;
//#if true
//	gk::String step1 = initialStr;
//	std::cout << step1 << '\n';
//	gk::Option<usize> beginFound = step1.find("->"_str);
//	gk::String sub = step1.substring(beginFound.some() + 2, step1.usedBytes());
//	std::cout << sub << '\n';
//	gk::Option<usize> endFound = sub.find(">(void)"_str);
//	if (endFound.none()) {
//		std::cout << "didnt find >(void)\n";
//	}
//	else {
//		gk::String variableName = sub.substring(0, sub.find(">(void)"_str).some());
//		std::cout << variableName << '\n';
//	}
//	
//#else
//	using std::string;
//
//	string step1 = initialStr.str;
//	std::cout << step1 << '\n';
//	size_t beginFound = step1.find("->");
//
//	string sub = step1.substr(beginFound + 2, step1.length() - (beginFound + 2));
//	std::cout << sub << '\n';
//	
//	size_t endFound = sub.find(">(void)");
//	if (endFound == std::string::npos) {
//		std::cout << "didnt find >(void)\n";
//	}
//	string variableName = sub.substr(0, sub.length() - 7);
//	std::cout << variableName << '\n';
//
//#endif

	check_lt(3, 2);
	std::cout << gk::getFieldName<&Example::ahskdjhaskjdhalskjdaaaa>() << '\n';
  //structName += " :>";
  //std::cout << structName;

  //get_field_names<Example>();
}