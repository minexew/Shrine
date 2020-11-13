# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
### Added
- World's worst HTTP server (in `Demo/Network/HtServ`)
- Functions `inet_ntop`, `inet_pton`
- Function `sendall`

### Changed
- `send` will no longer block until all data has been sent. The new behavior is consistend with blocking Berkeley sockets (the new function `sendall` can be used to get the previous behavior)

### Removed
- Functions `inet_aton`, `inet_ntoa`

### Fixed
- TCP server mode is now usable (`close` doesn't abruptly terminate the connection)

[Unreleased]: https://github.com/minexew/Shrine/compare/9317cf4f645a0072d5fa3f9abc466964d8baad4c...v5
