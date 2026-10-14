// Moody Glow - Logging Macro
// Developer: Moody
// Purpose: Disable logs in Release builds automatically

#ifndef MoodyGlowLog_h
#define MoodyGlowLog_h

#ifdef DEBUG
    #define MGLog(...) NSLog(__VA_ARGS__)
#else
    #define MGLog(...) do {} while (0)
#endif

#endif
