[![build-sdl3-ios-static](https://github.com/mosobman/build-sdl3-ios-static/actions/workflows/build-sdl3-ios-static.yml/badge.svg)](https://github.com/mosobman/build-sdl3-ios-static/actions/workflows/build-sdl3-ios-static.yml)

Automatic weekly build of [SDL3][] and its helper libraries, [FFmpeg][], [Dear ImGui][], and [Clay][] for iOS 15.0 (arm64).

Build produces static libraries (.a files) as well as their statically linked dependencies. FFmpeg is built from its `release/9.0` branch as static libraries, limited to `libavcodec`, `libavformat`, `libavutil`, and `libswresample`; the built-in codecs and formats are retained, the public headers are installed under `include/`, and all four libraries are included in `libSDL3_monolithic.a`.

Download binary build as zip archive from [latest release][] page.

To build locally run `build.sh` shell file, make sure you have installed all necessary dependencies (see the beginning of file).

[SDL3]: https://www.libsdl.org/
[FFmpeg]: https://ffmpeg.org/
[Dear ImGui]: https://github.com/ocornut/imgui
[Clay]: https://github.com/nicbarker/clay
[latest release]: https://github.com/mosobman/build-sdl3-ios-static/releases/latest
