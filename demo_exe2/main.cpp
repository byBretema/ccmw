#include <iostream>

#include <demo_lib1.hpp>
#include <demo_lib2.hpp>
#include <demo_lib3.hpp>
#include <demo_lib4.hpp>

int main() {
    std::cout << "Hello from demo2!\n";
    hello_demo_lib1();
    hello_demo_lib2();
    hello_demo_lib3();
    hello_demo_lib4();
    return 0;
}
