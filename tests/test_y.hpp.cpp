#define yyEnable_Aliases
#define yyLib_Glm
#define yyEnable_Testing

#include "y.hpp"

int main() {
    y::Test t;

    // y_fmt basic types
    t.eq("y_fmt int",   y_fmt("{}", 42),    "42");
    t.eq("y_fmt float", y_fmt("{:.1f}", 3.14f), "3.1");
    t.eq("y_fmt str",   y_fmt("{}", "hello"),   "hello");

    // GLM Vec3 formatter
    t.eq("Vec3", y_fmt("{}", y::Vec3{1, 2, 3}), "Vec3(1.00, 2.00, 3.00)");
    t.eq("Vec2", y_fmt("{}", y::Vec2{0.5f, 1.5f}), "Vec2(0.50, 1.50)");
    t.eq("Vec4", y_fmt("{}", y::Vec4{0, 0, 0, 1}), "Vec4(0.00, 0.00, 0.00, 1.00)");

    // Container formatting via fmt::ranges
    t.eq("Vec<int>",   y_fmt("{}", y::Vec<int>{1, 2, 3}),     "[1, 2, 3]");
    t.eq("Vec<Str>",   y_fmt("{}", y::Vec<y::Str>{"a", "b"}), R"(["a", "b"])");
    t.eq("empty Vec",  y_fmt("{}", y::Vec<int>{}),            "[]");

    // y_println compiles and runs (output is visible in test log)
    y_println("test y_println: {}", 42);

    t.show_results();
    return t.cli_result();
}
