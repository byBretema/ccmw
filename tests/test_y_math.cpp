#define yyEnable_Aliases
#define yyLib_Glm
#define yyEnable_Testing

#include "y.hpp"

int main() {
    y::Test t;
    t.set_align_column(55);

    t.ok("clamp",  y::clamp(5, 0, 10) == 5);
    t.ok("clamp_lo", y::clamp(-1, 0, 10) == 0);
    t.ok("clamp_hi", y::clamp(15, 0, 10) == 10);

    float mapped = y::map(50.0f, 0.0f, 100.0f, 0.0f, 1.0f);
    t.eq("map mid", y_fmt("{:.2f}", mapped), "0.50");

    t.ok("fuzzy_eq",   y::fuzzy_eq(1.0f, 1.001f, 0.01f));
    t.ok("!fuzzy_eq", !y::fuzzy_eq(1.0f, 1.1f, 0.01f));

    t.show_results();
    return t.cli_result();
}
