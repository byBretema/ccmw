
#ifndef DEMO_LIB2_API_H
#define DEMO_LIB2_API_H

#ifdef DEMO_LIB2_STATIC_DEFINE
#  define DEMO_LIB2_API
#  define DEMO_LIB2_NO_EXPORT
#else
#  ifndef DEMO_LIB2_API
#    ifdef demo_lib2_EXPORTS
        /* We are building this library */
#      define DEMO_LIB2_API __attribute__((visibility("default")))
#    else
        /* We are using this library */
#      define DEMO_LIB2_API __attribute__((visibility("default")))
#    endif
#  endif

#  ifndef DEMO_LIB2_NO_EXPORT
#    define DEMO_LIB2_NO_EXPORT __attribute__((visibility("hidden")))
#  endif
#endif

#ifndef DEMO_LIB2_DEPRECATED
#  define DEMO_LIB2_DEPRECATED __attribute__ ((__deprecated__))
#endif

#ifndef DEMO_LIB2_DEPRECATED_EXPORT
#  define DEMO_LIB2_DEPRECATED_EXPORT DEMO_LIB2_API DEMO_LIB2_DEPRECATED
#endif

#ifndef DEMO_LIB2_DEPRECATED_NO_EXPORT
#  define DEMO_LIB2_DEPRECATED_NO_EXPORT DEMO_LIB2_NO_EXPORT DEMO_LIB2_DEPRECATED
#endif

/* NOLINTNEXTLINE(readability-avoid-unconditional-preprocessor-if) */
#if 0 /* DEFINE_NO_DEPRECATED */
#  ifndef DEMO_LIB2_NO_DEPRECATED
#    define DEMO_LIB2_NO_DEPRECATED
#  endif
#endif

#endif /* DEMO_LIB2_API_H */
