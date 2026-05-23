//
//  MediaRemoteMRBridge.h
//  LyricsMTMR
//
//  C API exported by the MediaRemoteMRBridge.dylib.
//  The dylib is loaded by run.pl (Perl) — all functions are
//  compiled into a standalone .dylib and discovered via dlopen/dlsym.
//

#ifndef MediaRemoteMRBridge_h
#define MediaRemoteMRBridge_h

#ifdef __cplusplus
extern "C" {
#endif

void bootstrap(void);
void loop(void);
void play(void);
void pause_command(void);
void toggle_play_pause(void);
void next_track(void);
void previous_track(void);
void stop_command(void);
void update_player_state(void);
void set_time_from_env(void);

#ifdef __cplusplus
}
#endif

#endif /* MediaRemoteMRBridge_h */
