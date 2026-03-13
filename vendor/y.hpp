#pragma once

/*

    y.hpp

    An opinionated wrapper over many CPP utils.


--------------------------------------------------------------------------------

    yyLib_

        // #define yyLib_Fmt
        //     Include basic fmt header file(s) and expose, basic log methods:
        //     y_info/warn/err/debug. This will undefine 'yyCustom_Fmt'

        #define yyLib_Argparse
            Include argparse header file(s) and expose y::cli_xxx methods

        #define yyLib_Glm
            Include basic glm header files

--------------------------------------------------------------------------------

    yyCustom_

        // #define yyCustom_Fmt
        //     Include simplistic fmt-like custom implementation.
        //     It could be undefined by 'yyLib_Fmt'

--------------------------------------------------------------------------------

    yyEnable_

        #define yyEnable_Aliases
            Expose aliases defined in 'y' namespace :
            i32, f32, Vec, Arr, Str, Sptr, Uptr, Vec2, Vec3, ...

        #define yyEnable_Testing
            Include a class to easily run Tests.

        #define yyEnable_Benchmarking
            Include a class to easily run Benchmarks.

        #define yyEnable_PrintFileAndLine
            Include file and line info also on y_print not only on
y_info/warn...

--------------------------------------------------------------------------------

    yyDisable_

        #define yyDisable_LogFileAndLine
            Hide file and line on y_info/warn...

        #define yyDisable_Log
            Hide logs completely

--------------------------------------------------------------------------------

    Convetions

        - camelCase  : Defines            : Prefix 'yy'
        - snake_case : Macros             : Prefix 'y_'
        - PascalCase : Types + Namespaces : Inside 'y' namespace
        - PascalCase : Concepts           : Inside 'y' namespace. Prefix 'T_'
        - snake_case : Vars  + Funcs      : Inside 'y' namespace
        - m_ prefix  : Private vars
        - s_ prefix  : Static  vars

--------------------------------------------------------------------------------

    Copyright Daniel Brétema, 2025.
    Distributed under the Boost Software License, Version 1.0.
    See complete details at https://www.boost.org/LICENSE_1_0.txt

*/


// - - - - - - - - - - - - - - - - - INCLUDES - - - - - - - - - - - - - - - - //
#if 1

// std
#include <algorithm>
#include <array>
#include <cassert>
#include <chrono>
#include <cmath>
#include <concepts>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iso646.h>
#include <limits>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <span>
#include <string>
#include <string_view>
#include <thread> // IWYU pragma: keep
#include <unordered_map>
#include <unordered_set>
#include <vector>

// argparse
#ifdef yyLib_Argparse
//! https://github.com/p-ranav/argparse?tab=readme-ov-file#table-of-contents
#include <argparse/argparse.hpp>
#endif

// fmt
// #ifdef yyLib_Fmt
// #include <fmt/chrono.h>
// #include <fmt/format.h>
// #include <fmt/ranges.h>
// #include <fmt/std.h>
// #else
// #include <format>
// #endif
#include <format>

// glm
#ifdef yyLib_Glm
// #define GLM_FORCE_SSE
// #define GLM_FORCE_DEFAULT_ALIGNED_GENTYPES
#define GLM_ENABLE_EXPERIMENTAL
#define GLM_FORCE_SWIZZLE
#define GLM_FORCE_SILENT_WARNINGS
#define GLM_FORCE_RADIANS
#define GLM_FORCE_LEFT_HANDED
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <glm/gtx/string_cast.hpp> // Before of 'GLM_FORCE_INLINE'
#define GLM_FORCE_INLINE
#include <glm/glm.hpp>
#include <glm/gtc/constants.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/quaternion.hpp>
#include <glm/gtc/type_ptr.hpp>
#include <glm/gtx/component_wise.hpp>
#include <glm/gtx/euler_angles.hpp>
#include <glm/gtx/vec_swizzle.hpp>
#include <glm/gtx/vector_angle.hpp>
#define glmstr(x) glm::to_string(x)
#endif

#endif


// - - - - - - - - - - - - - - - QoL MACROS - - - - - - - - - - - - - - - - - //
#if 1

// Flow

#define y_or_return(cond, ret_val)                                                                                     \
    if (!(cond)) {                                                                                                     \
        return (ret_val);                                                                                              \
    }

// Class helpers

#define y_class_nocopy(T)                                                                                              \
public:                                                                                                                \
    T(T const &) = delete;                                                                                             \
    T &operator=(T const &) = delete;

#define y_class_nomove(T)                                                                                              \
public:                                                                                                                \
    T(T &&) noexcept = delete;                                                                                         \
    T &operator=(T &&) noexcept = delete;

#define y_class_nocopynomove(T) y_class_nocopy(T) y_class_nomove(T)

#define y_class_move(T, move_code)                                                                                     \
public:                                                                                                                \
    T(T &&rhs_) noexcept { *this = std::move(rhs_); }                                                                  \
    T &operator=(T &&rhs_) noexcept {                                                                                  \
        swap(*this, rhs_);                                                                                             \
        return *this;                                                                                                  \
    }                                                                                                                  \
    friend void swap(T &lhs, T &rhs) noexcept {                                                                        \
        if (&lhs == &rhs)                                                                                              \
            return;                                                                                                    \
        using std::swap;                                                                                               \
        move_code;                                                                                                   \
    }

// Concat

#ifndef __yConcat
#define __yConcat2(l, r) l##r
#define __yConcat1(l, r) __yConcat2(l, r)
#define __yConcat(l, r) __yConcat1(l, r)
#endif

// Defer

#define y_defer(x) y::Defer __yConcat(y_defer_r_, __LINE__) { [&] { x; } };
#define y_deferc(x) y::Defer __yConcat(y_defer_c_, __LINE__) { [=] { x; } };

#endif

// - - - - - - - - - - - - - - - - ALIASES  - - - - - - - - - - - - - - - - - //

namespace y {

////////////////////////////////////////////////////////////////////////////////
//                                 OTHERS                                     //
////////////////////////////////////////////////////////////////////////////////
#if 1

namespace fs = std::filesystem;

#endif

////////////////////////////////////////////////////////////////////////////////
//                                NUMBERs                                     //
////////////////////////////////////////////////////////////////////////////////
namespace Alias_Num {

// Bool

using b8 = bool;

// Unsigned

using u8 = uint8_t;
using u16 = uint16_t;
using u32 = uint32_t;
using u64 = uint64_t;
using usize = size_t;

inline constexpr u8 u8_min = std::numeric_limits<u8>::min();
inline constexpr u8 u8_max = std::numeric_limits<u8>::max();
inline constexpr u16 u16_min = std::numeric_limits<u16>::min();
inline constexpr u16 u16_max = std::numeric_limits<u16>::max();
inline constexpr u32 u32_min = std::numeric_limits<u32>::min();
inline constexpr u32 u32_max = std::numeric_limits<u32>::max();
inline constexpr u64 u64_min = std::numeric_limits<u64>::min();
inline constexpr u64 u64_max = std::numeric_limits<u64>::max();
inline constexpr usize usize_min = std::numeric_limits<usize>::min();
inline constexpr usize usize_max = std::numeric_limits<usize>::max();

// Signed

using i8 = int8_t;
using i16 = int16_t;
using i32 = int32_t;
using i64 = int64_t;
using isize = ptrdiff_t;

inline constexpr i8 i8_min = std::numeric_limits<i8>::min();
inline constexpr i8 i8_max = std::numeric_limits<i8>::max();
inline constexpr i16 i16_min = std::numeric_limits<i16>::min();
inline constexpr i16 i16_max = std::numeric_limits<i16>::max();
inline constexpr i32 i32_min = std::numeric_limits<i32>::min();
inline constexpr i32 i32_max = std::numeric_limits<i32>::max();
inline constexpr i64 i64_min = std::numeric_limits<i64>::min();
inline constexpr i64 i64_max = std::numeric_limits<i64>::max();
inline constexpr isize isize_min = std::numeric_limits<isize>::min();
inline constexpr isize isize_max = std::numeric_limits<isize>::max();

// Floating point

using f32 = float;
using f64 = double;

inline constexpr f32 f32_min = std::numeric_limits<f32>::min();
inline constexpr f32 f32_max = std::numeric_limits<f32>::max();
inline constexpr f32 f32_epsilon = std::numeric_limits<f32>::epsilon();

inline constexpr f64 f64_min = std::numeric_limits<f64>::min();
inline constexpr f64 f64_max = std::numeric_limits<f64>::max();
inline constexpr f64 f64_epsilon = std::numeric_limits<f64>::epsilon();

} // namespace Alias_Num
using namespace Alias_Num;

using ull = unsigned long long;
using ill = signed long long;
using fll = double long;


////////////////////////////////////////////////////////////////////////////////
//                                  STL                                       //
////////////////////////////////////////////////////////////////////////////////
namespace Alias_Stl {

// Unique pointer
template <typename T>
using Uptr = std::unique_ptr<T>;

template <typename T, typename... Args>
[[nodiscard]] inline constexpr Uptr<T> u_new(Args &&...args) {
    return std::make_unique<T>(std::forward<Args>(args)...);
}

// Shared pointer
template <typename T>
using Sptr = std::shared_ptr<T>;

template <typename T, typename... Args>
[[nodiscard]] inline constexpr Sptr<T> s_new(Args &&...args) {
    return std::make_shared<T>(std::forward<Args>(args)...);
}

// Unordered Map
template <typename K, typename V>
using Umap = std::unordered_map<K, V>;

// Ordered Map
template <typename K, typename V>
using Omap = std::map<K, V>;

// Unordered Set
template <typename T>
using Uset = std::unordered_set<T>;

// Ordered Set
template <typename T>
using Oset = std::set<T>;

// Dynamic Array
template <typename T>
using Vec = std::vector<T>;

// Array
template <typename T, size_t S>
using Arr = std::array<T, S>;

// Optional
template <typename T>
using Opt = std::optional<T>;
template <typename T>
using OptRef = std::optional<std::reference_wrapper<T>>;

// String
using Str = std::string;
using StrView = std::string_view;

// Function
template <typename T>
using Fn = std::function<T>;
using VoidFn = Fn<void()>;
using BoolFn = Fn<bool()>;

// Span
template <typename T>
using Span = std::span<T>;
template <typename T>
using SpanConst = std::span<const T>;

// Chrono
using Clock = std::chrono::high_resolution_clock;
using TimePoint = Clock::time_point;

} // namespace Alias_Stl
using namespace Alias_Stl;


////////////////////////////////////////////////////////////////////////////////
//                                  GLM                                       //
////////////////////////////////////////////////////////////////////////////////
namespace Alias_Glm {
#ifdef yyLib_Glm

using Vec2 = glm::vec2;
using Vec3 = glm::vec3;
using Vec4 = glm::vec4;

using Mat4 = glm::mat4;

#endif
} // namespace Alias_Glm
using namespace Alias_Glm;


} // namespace y


// - - - - - - - - - - - - - - - - CONCEPTS - - - - - - - - - - - - - - - - - //
namespace y {

template <typename T, typename... Allowed>
concept T_OneOf = (std::same_as<T, Allowed> || ...);

template <typename T>
concept T_Container = std::ranges::range<T> && !std::convertible_to<T, y::StrView>;

template <typename T>
concept T_Integer = std::integral<T>;

template <typename T>
concept T_Decimal = std::floating_point<T>;

template <typename T>
concept T_Number = std::integral<T> || std::floating_point<T>;

template <typename T>
concept T_CharList = std::same_as<T, Vec<u8>> || requires(T const &t) {
    { t.data() } -> std::convertible_to<const char *>;
    { t.size() } -> std::integral;
};


#ifdef yyLib_Glm

template <typename T>
concept T_MathVec = T_OneOf<T, Vec2, Vec3, Vec4>;

#endif

} // namespace y


// - - - - - - - - - - - - - - - - FORMATTERs - - - - - - - - - - - - - - - - //
#if 1

// Containers formatter
template <y::T_Container T>
struct std::formatter<T> {
    constexpr auto parse(std::format_parse_context &ctx) { return ctx.begin(); }
    auto format(const T &container, std::format_context &ctx) const {
        auto out = ctx.out();

        std::format_to(out, "{{ ");

        bool first = true;
        for (const auto &item : container) {
            if (!first)
                std::format_to(out, ", ");
            std::format_to(out, "{}", item);
            first = false;
        }

        return std::format_to(out, " }}");
    }
};


#ifdef yyLib_Glm

// Math Vectors formatter
template <y::T_MathVec T>
struct std::formatter<T> {
    constexpr auto parse(std::format_parse_context &ctx) { return ctx.begin(); }
    auto format(const T &v, std::format_context &ctx) const {
        int const f = 2; // Amount of decimals  // TODO : Set this as setting field
        if constexpr (std::is_same_v<T, y::Vec2>)
            return std::format_to(ctx.out(), "Vec2({:.{}f}, {:.{}f})", v.x, f, v.y, f);
        if constexpr (std::is_same_v<T, y::Vec3>)
            return std::format_to(ctx.out(), "Vec3({:.{}f}, {:.{}f}, {:.{}f})", v.x, f, v.y, f, v.z, f);
        if constexpr (std::is_same_v<T, y::Vec4>)
            return std::format_to(ctx.out(), "Vec4({:.{}f}, {:.{}f}, {:.{}f})", v.x, f, v.y, f, v.z, f, v.w, f);
        return std::format_to(ctx.out(), "Vec?()");
    }
};

#endif
#endif


// - - - - - - - - - - - - - -  FORMAT / PRINT  - - - - - - - - - - - - - - - //
#ifndef yyDisable_Log

#ifdef _WIN32
#include <windows.h>
static const int __yWinCoutSetup = []() {
    SetConsoleOutputCP(CP_UTF8);
    return 0;
}();
#endif

#define y_fmt std::format
#define __yPrinter(...) printf("%s", y_fmt(__VA_ARGS__).c_str())

#ifndef yyDisable_LogFileAndLine
#define __yLogInfo(level) y_fmt("[{}] | {}:{} | ", level, __FILE__, __LINE__)
#else
#define __yLogInfo(level) y_fmt("[{}] | ", level)
#endif

#ifdef yyEnable_PrintFileAndLine
#define __yPrintInfo() y_fmt("[PRNT] | {}:{} | ", __FILE__, __LINE__)
#else
#define __yPrintInfo() ""
#endif

#define y_info(...) __yPrinter("{}{}\n", __yLogInfo("INFO"), y_fmt(__VA_ARGS__))
#define y_warn(...) __yPrinter("{}{}\n", __yLogInfo("WARN"), y_fmt(__VA_ARGS__))
#define y_err(...) __yPrinter("{}{}\n", __yLogInfo("ERRO"), y_fmt(__VA_ARGS__))
#define y_debug(...) __yPrinter("{}{}\n", __yLogInfo("DEBG"), y_fmt(__VA_ARGS__))

#define y_println(...) __yPrinter("{}{}\n", __yPrintInfo(), y_fmt(__VA_ARGS__))
#define y_print(...) __yPrinter("{}{}", __yPrintInfo(), y_fmt(__VA_ARGS__))

namespace y::nasty {
namespace z {
inline static FILE *s_stdout = nullptr;
} // namespace z

[[maybe_unused]] static void stdout_off() {
    std::fflush(stdout);
#ifdef _WIN32
    s_stdout = freopen("NUL", "w", stdout);
#else
    z::s_stdout = freopen("/dev/null", "w", stdout);
#endif
}

[[maybe_unused]] static void stdout_on() {
    std::fflush(stdout);
    if (!z::s_stdout)
        return;
#ifdef _WIN32
    freopen("CON", "w", stdout); // Windows console device
#else
    freopen("/dev/tty", "w", stdout); // Linux/macOS console device
#endif
    z::s_stdout = nullptr;
}
} // namespace y::nasty

#endif


// - - - - - - - - - - - - - - - - - CORE - - - - - - - - - - - - - - - - - - //
namespace y {

////////////////////////////////////////////////////////////////////////////////
//                          RESOURCES MANAGEMENT                              //
////////////////////////////////////////////////////////////////////////////////
#if 1

template <typename T>
struct Defer final {
    Defer(T &&callback) : m_callback(std::forward<T>(callback)) {}
    y_class_nocopynomove(Defer);
    ~Defer() { m_callback(); }

private:
    const T m_callback;
};


struct LazyGC final {

    y_class_nocopy(LazyGC);
    y_class_move(LazyGC, { lhs.m_callbacks = rhs.m_callbacks; });

    ~LazyGC() { release(); }

    LazyGC &add(VoidFn &&cb) {
        assert(cb);
        if (cb) {
            m_callbacks.emplace_back(std::forward<VoidFn>(cb));
            m_done = false;
        }
        return *this;
    }

    void release() {
        if (!m_done) {
            for (auto &callback : m_callbacks) {
                callback();
            }
        }
        m_callbacks.clear();
        m_done = true;
    }

private:
    Vec<VoidFn> m_callbacks {};
    bool m_done { true };
};

#endif

////////////////////////////////////////////////////////////////////////////////
//                                 OTHERs                                     //
////////////////////////////////////////////////////////////////////////////////
#if 1

template <typename F, typename T>
auto bind(F &&fn, T *obj) {
    return [obj, fn](auto &&...args) -> decltype(auto) { return (obj->*fn)(std::forward<decltype(args)>(args)...); };
}

[[nodiscard]] constexpr inline usize bit(usize n) { return (1 << n); }

#endif

////////////////////////////////////////////////////////////////////////////////
//                                 ARGPARSE                                   //
////////////////////////////////////////////////////////////////////////////////
#ifdef yyLib_Argparse

using CLI = argparse::ArgumentParser;

[[nodiscard]] CLI &cli_init(Str const &title, Str const &version, Str const &description) {
    static CLI cli { title, version };
    static auto once = [&description] {
        cli.add_description(description);
        return 0;
    }();
    return cli;
}

[[nodiscard]] bool cli_parse(CLI &cli, int argc, char *argv[]) {
    try {
        cli.parse_args(argc, argv);
        return true;
    } catch (const std::exception &err) {
        y_println("{}", err.what());
        y_println("{}", cli.help().str());
        return false;
    } catch (...) {
        y_println("{}", cli.help().str());
        return false;
    }
}

#endif


////////////////////////////////////////////////////////////////////////////////
//                                  TIME                                      //
////////////////////////////////////////////////////////////////////////////////
#if 1

// From Secs
inline constexpr f64 s_to_ms = 1e+3;
inline constexpr f64 s_to_us = 1e+6;
inline constexpr f64 s_to_ns = 1e+9;

// From Ms
inline constexpr f64 ms_to_s = 1e-3;
inline constexpr f64 ms_to_us = 1e+3;
inline constexpr f64 ms_to_ns = 1e+6;

// From Us
inline constexpr f64 us_to_s = 1e-6;
inline constexpr f64 us_to_ms = 1e-3;
inline constexpr f64 us_to_ns = 1e+3;

// From Ns
inline constexpr f64 ns_to_s = 1e-9;
inline constexpr f64 ns_to_ms = 1e-6;
inline constexpr f64 ns_to_us = 1e-3;


class ElapsedTimer {
public:
    [[nodiscard]] f64 elapsed_s() const { return f64(elapsed()) * ns_to_s; }
    [[nodiscard]] f64 elapsed_ms() const { return f64(elapsed()) * ns_to_ms; }
    [[nodiscard]] f64 elapsed_us() const { return f64(elapsed()) * ns_to_us; }
    [[nodiscard]] f64 elapsed_ns() const { return f64(elapsed()); }

    [[nodiscard]] b8 is_valid() const { return m_valid; }

    ElapsedTimer &reset() {
        m_valid = true;
        m_ref = Clock::now();
        return *this;
    }

private:
    [[nodiscard]] i64 elapsed() const {
        auto const now = Clock::now();
        auto const diff = now - m_ref;
        using timeunit = std::chrono::nanoseconds;
        return std::chrono::duration_cast<timeunit>(diff).count();
    }

    TimePoint m_ref = Clock::now();
    b8 m_valid = false;
};

/// Returns current time formatted as `DD-MM-YYYY HH-MM-SS`
Str inline time_stamp() {
    auto const t = Clock::to_time_t(Clock::now());
    std::ostringstream oss;
    oss << std::put_time(std::localtime(&t), "%d-%m-%Y %H-%M-%S");
    return oss.str();
}

using ETimer = ElapsedTimer;

#endif


////////////////////////////////////////////////////////////////////////////////
//                                 STRINGS                                    //
////////////////////////////////////////////////////////////////////////////////
#if 1

[[nodiscard]] inline Str str_lower(Str str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    return str;
}

[[nodiscard]] inline Str str_upper(Str str) {
    std::transform(str.begin(), str.end(), str.begin(), ::toupper);
    return str;
}

[[nodiscard]] inline Str str_capital(Str str) {
    std::transform(str.begin(), str.end(), str.begin(), ::tolower);
    std::transform(str.begin(), str.begin() + 1, str.begin(), ::toupper);
    return str;
}

[[nodiscard]] inline b8 str_contains(StrView str, StrView substr) { return str.find(substr) != std::string::npos; }

[[nodiscard]] inline Vec<Str> str_split(StrView str, StrView delim) {
    if (delim.empty()) {
        return {};
    }

    Vec<Str> splitted {};
    usize ini = 0, end = 0;

    while ((end = str.find(delim, ini)) < str.size()) {
        splitted.push_back(Str(str.substr(ini, end - ini)));
        ini = end + delim.size();
    }

    if (ini < str.size())
        splitted.push_back(Str(str.substr(ini)));

    return splitted;
}

[[nodiscard]] inline Str str_join(Vec<Str> const &strlist, Str const &delim) {
    if (strlist.empty() || delim.empty()) {
        return "";
    }

    Str s;
    s.reserve(strlist.size() + (delim.size() * strlist.size() + 4));

    for (usize i = 0; i < strlist.size() - 1; ++i) {
        s += strlist[i] + delim;
    }
    s += strlist[strlist.size() - 1];

    return s;
}

[[nodiscard]] inline Str str_replace(Str str, Str const &from, Str const &to, b8 only_first_match = false) {
    usize pos = 0;
    while ((pos = str.find(from)) < str.size()) {
        str.replace(pos, from.length(), to);
        if (only_first_match) {
            break;
        }
    }
    return str;
}

[[nodiscard]] inline Str str_replace_many(Str str, Vec<Str> const &from, Vec<Str> const &to, b8 sorted = false) {
    b8 const same_size = from.size() == to.size();
    b8 const is_empty = same_size && from.size() < 1;
    if (!same_size || is_empty) {
        // y_warn("str_replace_many - {}", Str("Bad sizes. Returned original
        // str"));
        return str;
    }

    usize pos = 0;
    usize i = 0;
    usize anchor = 0;
    while (i < from.size() && (pos = str.find(from[i], anchor)) < str.size()) {
        str.replace(pos, from[i].length(), to[i]);
        if (sorted) {
            anchor = pos;
        }
        ++i;
    }
    return str;
}

[[nodiscard]] inline Str str_slice(Str const &str, usize from, usize to) {
    if (to < 1 || to < from || to > str.size()) {
        y_warn("str_slice / str_cut - {}", "Bad range. Returned original str");
        return str;
    }
    return str.substr(from, to);
}

[[nodiscard]] inline Str str_cut(Str const &str, usize count) { return str_slice(str, count, str.size() - count * 2); }

[[nodiscard]] inline Str str_cut_l(Str const &str, usize count) { return str_slice(str, count, str.size()); }

[[nodiscard]] inline Str str_cut_r(Str const &str, usize count) { return str_slice(str, 0, str.size() - count); }

[[nodiscard]] inline Str str_trim_l(Str str, Str const &individual_chars_to_remove = " \n\r\t") {
    return str.erase(0, str.find_first_not_of(individual_chars_to_remove));
}

[[nodiscard]] inline Str str_trim_r(Str str, Str const &individual_chars_to_remove = " \n\r\t") {
    return str.erase(str.find_last_not_of(individual_chars_to_remove) + 1);
}

[[nodiscard]] inline Str str_trim(Str str, Str const &individual_chars_to_remove = " \n\r\t") {
    auto const l = str_trim_l(str, individual_chars_to_remove);
    return str_trim_r(l, individual_chars_to_remove);
}

#endif


////////////////////////////////////////////////////////////////////////////////
//                                   SPANs                                    //
////////////////////////////////////////////////////////////////////////////////

// template<typename T>
// [[nodiscard]] inline Span<T> make_span(auto &container, i32 first, i32 last=-1) {

// }


////////////////////////////////////////////////////////////////////////////////
//                                   FILEs                                    //
////////////////////////////////////////////////////////////////////////////////
#if 1

[[nodiscard]] inline Str file_read(Str const &input_file) {

    std::ifstream file(input_file, std::ios::ate | std::ios::binary);
    y_defer(file.close());

    if (!file.is_open()) {
        y_warn("[file_read] Opening file: {}. Returned empty str.", input_file);
        return "";
    }

    Str content;
    content.resize(file.tellg());
    file.seekg(0, std::ios::beg);
    file.read(&content[0], content.size());

    return content;
}

inline b8 file_write(Str const &output_file, char const *data, usize data_size, std::ios_base::openmode mode) {

    if (!data || data_size < 1) {
        y_err("[file_write] Invalid data: {}", output_file);
        return false;
    }

    fs::create_directory(fs::path(output_file).parent_path());

    std::ofstream file(output_file, std::ios::out | std::ios::binary | mode);
    y_defer(file.close());

    if (!file.is_open()) {
        y_err("[file_write] Opening file: {}", output_file);
        return false;
    }

    file.write(data, data_size);

    return true;
}

template <T_CharList T>
inline b8 file_append(Str const &output_file, T const &v) {
    return file_write(output_file, (char const *)(v.data()), v.size(), std::ios::app);
}

template <T_CharList T>
inline b8 file_overwrite(Str const &output_file, T const &v) {
    return file_write(output_file, (char const *)(v.data()), v.size(), std::ios::trunc);
}

inline b8 file_check_extension(Str const &input_file, Str ext_ref) {
    auto const ext = input_file.substr(input_file.find_last_of('.') + 1);
    return str_lower(ext) == str_lower(ext_ref);
}

#endif


////////////////////////////////////////////////////////////////////////////////
//                                  BINARY                                    //
////////////////////////////////////////////////////////////////////////////////
#if 1


[[nodiscard]] inline Vec<u8> bin_read(Str const &path) {
    std::ifstream file { path, std::ios::binary };
    using FileIt = std::istreambuf_iterator<char>;
    return { FileIt(file), FileIt() }; // Start, End
}

[[nodiscard]] inline b8 bin_check_magic(SpanConst<u8> bin, SpanConst<u8> magic) {
    // Validation
    if (magic.empty() || bin.size() < magic.size()) {
        return false;
    }
    // Iteration
    b8 match = true;
    for (usize i = 0; i < magic.size(); ++i) {
        match &= (bin[i] == magic[i]);
    }
    // Result
    return match;
}

#endif


////////////////////////////////////////////////////////////////////////////////
//                                  MATHs                                     //
////////////////////////////////////////////////////////////////////////////////
#if 1

template <T_Number T>
[[nodiscard]] constexpr inline T clamp(T v, T lo, T hi) {
    assert(lo >= hi);
    return std::max(lo, std::min(v, hi));
}

template <T_Decimal T>
[[nodiscard]] constexpr inline T map(T value, T src_min, T src_max, T dst_min, T dst_max) {
    return dst_min + (dst_max - dst_min) * (value - src_min) / (src_max - src_min);
}

template <T_Decimal T>
[[nodiscard]] constexpr inline T map_100(T value, T dst_min, T dst_max) {
    return map(value, 0, 100, dst_min, dst_max);
}

template <T_Decimal T>
[[nodiscard]] constexpr inline b8 fuzzy_eq(T f1, T f2, T threshold = 0.01f) {
    auto const diff = abs(f1 - f2);
    auto const is_eq = diff <= threshold;
    return is_eq;
}

template <T_Decimal T>
[[nodiscard]] constexpr inline T clamp_angle(T angle) {
    auto const turns = floorf(angle / 360.f);
    return angle - 360.f * turns;
}


#ifdef yyLib_Glm

[[nodiscard]] constexpr inline b8 fuzzy_eq(Vec2 const &v1, Vec2 const &v2, f32 t = 0.01f) {
    return fuzzy_eq(v1.x, v2.x, t) && fuzzy_eq(v1.y, v2.y, t);
}

[[nodiscard]] constexpr inline b8 fuzzy_eq(Vec3 const &v1, Vec3 const &v2, f32 t = 0.01f) {
    return fuzzy_eq(v1.x, v2.x, t) && fuzzy_eq(v1.y, v2.y, t) && fuzzy_eq(v1.z, v2.z, t);
}

[[nodiscard]] constexpr inline b8 fuzzy_eq(Vec4 const &v1, Vec4 const &v2, f32 t = 0.01f) {
    return fuzzy_eq(v1.x, v2.x, t) && fuzzy_eq(v1.y, v2.y, t) && //
           fuzzy_eq(v1.z, v2.z, t) && fuzzy_eq(v1.w, v2.w, t);
}

template <typename T>
[[nodiscard]] constexpr inline b8 is_aligned(T const &a, T const &b, f32 margin = 0.01f) {
    return abs(glm::dot(glm::normalize(a), glm::normalize(b))) >= (1.f - f32_epsilon - margin);
}
#endif

#endif


////////////////////////////////////////////////////////////////////////////////
//                                  TESTs                                     //
////////////////////////////////////////////////////////////////////////////////
#ifdef yyEnable_Testing

class Test {

public:
    void make_section(StrView name) { m_section = name; }

    void ok(StrView title, bool c) {
        test(title, [&] { return c; }, "Condition is false");
    }

    template <typename T1, typename T2>
    void eq(StrView title, T1 const &lhs, T2 const &rhs) {
        test(title, [&] { return lhs == rhs; }, y_fmt("{} == {}", lhs, rhs));
    }

    template <typename T1, typename T2>
    void gt(StrView title, T1 const &lhs, T2 const &rhs) {
        test(title, [&] { return lhs > rhs; }, y_fmt("{} > {}", lhs, rhs));
    }

    template <typename T1, typename T2>
    void lt(StrView title, T1 const &lhs, T2 const &rhs) {
        test(title, [&] { return lhs < rhs; }, y_fmt("{} < {}", lhs, rhs));
    }

    template <typename T1, typename T2>
    void gt_or_eq(StrView title, T1 const &lhs, T2 const &rhs) {
        test(title, [&] { return lhs >= rhs; }, y_fmt("{} >= {}", lhs, rhs));
    }

    template <typename T1, typename T2>
    void lt_or_eq(StrView title, T1 const &lhs, T2 const &rhs) {
        test(title, [&] { return lhs <= rhs; }, y_fmt("{} <= {}", lhs, rhs));
    }

    void show_results() {
        bool const done = m_pass_count == m_total_count;
        // y_println("");

        if (m_pass_count and not done)
            y_println("✅ PASS  |  {} / {}", m_pass_count, m_total_count);

        if (m_fail_count)
            y_println("❌ FAIL  |  {} / {}", m_fail_count, m_total_count);

        // if (done)
        //     y_println("🏁 DONE  |  {} / {}", m_pass_count, m_total_count);
    }

    i32 cli_result() { return m_pass_count == m_total_count ? 0 : -1; }

    void set_align_column(usize col) { m_align_col = std::clamp(col, 0ul, 255ul); }

    void test(StrView title, Fn<bool()> const &fn, StrView msg = "") {
        if (!fn) {
            on_failed(title, y_fmt("Invalid callback -- {}", msg));
        }
        on_start();
        try {
            fn() ? on_passed() : on_failed(title, msg);
        } catch (const std::exception &err) {
            on_failed(title, y_fmt("{} -- {}", err.what(), msg));
        } catch (...) {
            on_failed(title, y_fmt("??? -- {}", msg));
        }
    }


private:
    void on_start() { ++m_total_count; }

    void on_passed() { ++m_pass_count; }

    void on_failed(StrView title, StrView msg) {
        Str const msg_l = y_fmt("⭕️ {} -> {}", m_section, title);
        usize const sep_len = m_align_col > msg_l.size() ? m_align_col - msg_l.size() : 0ul;
        Str const sep = Str(sep_len, ' ');
        y_println("{}{}  |  {}", msg_l, sep, msg);
        ++m_fail_count;
    }

    StrView m_section = "";
    u32 m_total_count = 0;
    u32 m_pass_count = 0;
    u32 m_fail_count = 0;
    usize m_align_col = 0;
};

#endif


////////////////////////////////////////////////////////////////////////////////
//                                BENCHMARKS                                  //
////////////////////////////////////////////////////////////////////////////////
#ifdef yyEnable_Benchmarking

class Benchmark {

public:
    void run(StrView title, u32 executions, Fn<void()> const &callback) {

        if (!callback) {
            y_warn("⭕️ {} x {} invalid callback", title, executions);
        }

        nasty::stdout_off();

        u32 i = 0;
        auto et = ETimer {}.reset();
        for (; i < executions; ++i) {
            callback();
        }
        auto const elapsed = et.elapsed_ms();

        nasty::stdout_on();

        Str const msg_l = y_fmt("⌚ {} x {}", title, executions);
        Str const msg_r = y_fmt("{} ms", elapsed);
        usize const sep_len = m_align_col > msg_l.size() ? m_align_col - msg_l.size() : 0ul;
        Str const sep = Str(sep_len, ' ');
        y_println("{}{}  |  {}", msg_l, sep, msg_r);
    }

    void set_align_column(usize col) { m_align_col = std::clamp(col, 0ul, 255ul); }

private:
    usize m_align_col = 0;
};

#endif

} // namespace y


// - - - - - - - - - - - - - - - - ALIASES  - - - - - - - - - - - - - - - - - //
#ifdef yyEnable_Aliases

using namespace y::Alias_Num;
using namespace y::Alias_Glm;
using namespace y::Alias_Stl;

#endif
