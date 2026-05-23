# Changelog

All notable changes to MediaRemoteAdapter will be documented in this file.

## [1.0.1] - 2026-01-20

### Fixed

- **Critical: Fixed pipe deadlock in `runPerlCommand`** that caused the application to become unresponsive.

  **Root Cause:** When executing synchronous Perl commands (e.g., `updatePlayerState`, `play`, `pause`), the method called `waitUntilExit()` before reading from the output pipe. If the child process wrote more data than the pipe buffer could hold (~64KB), the write would block, preventing the process from exiting. This created a deadlock where:
  1. The parent waited for the child to exit
  2. The child waited for the parent to read the pipe

  **Impact:** Each deadlocked call consumed a GCD thread. After ~64 calls, the dispatch thread pool was exhausted, causing the entire application to freeze (windows couldn't close, UI unresponsive).

  **Solution:** Implemented asynchronous pipe reading using `readabilityHandler` to continuously drain the pipe buffer while waiting for the process to exit.

## [1.0.0] - Initial Release

- Initial implementation of MediaRemoteAdapter
- Swift interface for macOS media control via private MediaRemote.framework
- Perl-based sandboxing bridge for entitlement bypass
- Support for track info, playback state, and media commands
