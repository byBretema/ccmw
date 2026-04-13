#define yyEnable_Aliases
#define yyLib_Glm
#include "../vendor/y.hpp"

// #include <glm/glm.hpp>

int main(i32 argc, char **argv) {
    Vec<StrView> args(argv + 1, argv + argc);

    if (args.empty() or args[0] == "-h" or args[0] == "--help") {
        y_println("Usage demo <text> [options]");
        exit(1);
    }

    StrView const text = args[0];
    y_info("{} : {}", text, glm::vec3{1, 2, 3});

}
