#ifndef platform_h
#define platform_h

#if defined(__APPLE__) && defined(__MACH__)
#include <TargetConditionals.h>
#  if TARGET_OS_IPHONE == 1
#    undef HAS_MAIN
#  elif TARGET_OS_MAC == 1
#    if !defined(HAS_MAIN)
#      undef HAS_MAIN
#    endif
#  endif
#elif defined(__linux__)
#  define HAS_MAIN 1
#endif

#endif  /* platfrom_h */

