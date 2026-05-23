#define yyEnable_Aliases
#define yyEnable_Testing

#include "y.hpp"

int main() {
    y::Test t;
    t.set_align_column(55);

    t.eq("str_lower",    y::str_lower("HELLO"),            "hello");
    t.eq("str_upper",    y::str_upper("hello"),            "HELLO");
    t.eq("str_contains", y::str_contains("hello world", "world"), true);
    t.eq("str_split",    y::str_split("a,b,c", ",").size(), 3ul);
    t.eq("str_join",     y::str_join({"x", "y"}, "-"),     "x-y");
    t.eq("str_trim",     y::str_trim("  hi  "),            "hi");
    t.eq("str_replace",  y::str_replace("aba", "a", "z"),  "zbz");
    t.eq("str_cut_l",    y::str_cut_l("hello", 2),         "llo");
    t.eq("str_cut_r",    y::str_cut_r("hello", 2),         "hel");

    t.show_results();
    return t.cli_result();
}
