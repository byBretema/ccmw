#define yyEnable_Aliases
#include "../vendor/y.hpp"

void build(Span<StrView> args) {

    std::string_view target = "all";

    for (size_t i = 0; i < args.size(); ++i) {

        bool const not_last = i + 1 < args.size();
        bool const is_target = (args[i] == "--target" || args[i] == "-t");

          if (is_target && not_last) {
            target = args[++i];
            break;
        }
    }

    y_info("Building target: {}", target);
}

int main(i32 argc, char **argv) {
    Vec<StrView> args(argv + 1, argv + argc);

    if (args.empty() or args[0] == "-h" or args[0] == "--help") {
        y_println("Usage ccmw <command> [options]");
        return 0;
    }

    StrView const command = args[0];

    if (command == "build")
        build(Span{args.begin()+1, args.end()});

    return 0;
}
