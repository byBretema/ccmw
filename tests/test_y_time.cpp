#define yyEnable_Aliases
#define yyEnable_Testing

#include "y.hpp"
#include <thread>

int main() {
    y::Test t;
    t.set_align_column(55);

    y::ETimer timer;
    timer.reset();
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    auto elapsed = timer.elapsed_ms();
    t.ok("timer > 5ms", elapsed > 5.0);

    y::Str stamp = y::time_stamp();
    t.ok("stamp not empty", !stamp.empty());
    t.ok("stamp has '-'",   y::str_contains(stamp, "-"));
    t.ok("stamp has ' '",   y::str_contains(stamp, " "));

    t.show_results();
    return t.cli_result();
}
