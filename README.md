
# Build Monolithic Libraries

[![build-sdl3-ios-static](https://github.com/mosobman/build-sdl3-ios-static/actions/workflows/build-sdl3-ios-static.yml/badge.svg)](https://github.com/mosobman/build-sdl3-ios-static/actions/workflows/build-sdl3-ios-static.yml)

Automatic weekly build of [SDL3][] and its helper libraries, [FFmpeg][], [Dear ImGui][], and [Clay][] for iOS 15.0 (arm64).

Build produces four separate static-library packages: SDL3 and its helper libraries (including `libSDL3_monolithic.a`), FFmpeg, ImGui, and Clay. Each ZIP contains that package's headers and static libraries. FFmpeg is built from its `release/9.0` branch with `libavcodec`, `libavformat`, `libavutil`, and `libswresample`; the built-in codecs and formats are retained.

Release asset names use `LIBRARY-iOS-ios_target-SDK-sdk_version-YYYY-MM-DD.zip`, for example `FFmpeg-iOS-15.0-SDK-16.5-2026-11-24.zip`. Local builds place the ZIPs in `artifacts/`.

Download binary build as zip archive from [latest release][] page.

To build locally run `build.sh` shell file, make sure you have installed all necessary dependencies (see the beginning of file).

[SDL3]: https://www.libsdl.org/
[FFmpeg]: https://ffmpeg.org/
[Dear ImGui]: https://github.com/ocornut/imgui
[Clay]: https://github.com/nicbarker/clay
[latest release]: https://github.com/mosobman/build-sdl3-ios-static/releases/latest
