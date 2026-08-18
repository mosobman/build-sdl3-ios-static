#!/usr/bin/env bash
set -euo pipefail

TARGET_PLATFORM="$1"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

OUTPUT="$SCRIPT_DIR/SDL3-${TARGET_PLATFORM}"
SOURCE="$SCRIPT_DIR/sources"
BUILD="$SCRIPT_DIR/builds"
rm -rf "$OUTPUT"
rm -rf "$SOURCE"
rm -rf "$BUILD"
mkdir -p "$OUTPUT" || { echo "cannot create output path" >&2; exit 1; }
mkdir -p "$SOURCE" || { echo "cannot create source path" >&2; exit 1; }
mkdir -p "$BUILD"  || { echo "cannot create build path"  >&2; exit 1; }
echo "OUTPUT: $OUTPUT"
echo "SOURCE: $SOURCE"
echo "BUILD: $BUILD"

git_clone() {
	if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        echo "Error: Missing arguments." >&2
        echo "Usage: git_clone <dir_name> <repo_url> <branch>" >&2
        return 1
    fi
	cd "$SOURCE" || return 1

    if [ -d "$1" ]; then
        echo "Updating $1..."
        git -C "$1" clean --quiet -fdx
        git -C "$1" fetch --quiet --no-tags origin "$3":refs/remotes/origin/"$3" || return 1
        git -C "$1" reset --quiet --hard origin/"$3"                             || return 1
    else
        echo "Cloning $1..."
        git clone --quiet --branch "$3" --no-tags --depth 1 "$2" "$1" || return 1
    fi

	cd - > /dev/null || return 1
}

#
# Xcode Environment
#

command -v git >/dev/null   || { echo "git not found"   >&2; exit 1; }
command -v cmake >/dev/null || { echo "cmake not found" >&2; exit 1; }
command -v xcrun >/dev/null || { echo "xcrun not found" >&2; exit 1; }

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CC="$(xcrun --sdk iphoneos --find clang)"
CXX="$(xcrun --sdk iphoneos --find clang++)"
OBJCC="$(xcrun --sdk iphoneos --find clang)"
OBJCXX="$(xcrun --sdk iphoneos --find clang++)"
CLANG_VER="$($CC --version)"

IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-15.0}"
IOS_ARCH="${IOS_ARCH:-arm64}"

mkdir -p "$OUTPUT/compiler-rt"
cp -a "$(clang -print-resource-dir)/lib/darwin/libclang_rt.ios.a" "$OUTPUT/compiler-rt/"

echo "SDK: $SDK"
echo "Architecture: $IOS_ARCH"
echo "Deployment target: $IOS_DEPLOYMENT_TARGET"
echo "Compiler Version: $CLANG_VER"

#
# Downloading & Unpacking
#

git_clone SDL             "https://github.com/libsdl-org/SDL"             main || { echo "Failed to clone SDL"             >&2; exit 1; }
git_clone SDL_image       "https://github.com/libsdl-org/SDL_image"       main || { echo "Failed to clone SDL_image"       >&2; exit 1; }
git_clone SDL_mixer       "https://github.com/libsdl-org/SDL_mixer"       main || { echo "Failed to clone SDL_mixer"       >&2; exit 1; }
git_clone SDL_ttf         "https://github.com/libsdl-org/SDL_ttf"         main || { echo "Failed to clone SDL_ttf"         >&2; exit 1; }
#git_clone SDL_rtf         "https://github.com/libsdl-org/SDL_rtf"         main || { echo "Failed to clone SDL_rtf"         >&2; exit 1; }
#git_clone SDL_net         "https://github.com/libsdl-org/SDL_net"         main || { echo "Failed to clone SDL_net"         >&2; exit 1; }
#git_clone SDL_sound       "https://github.com/icculus/SDL_sound"          main || { echo "Failed to clone SDL_sound"       >&2; exit 1; }
#git_clone SDL_shadercross "https://github.com/libsdl-org/SDL_shadercross" main || { echo "Failed to clone SDL_shadercross" >&2; exit 1; }
#git_clone SDL2_compat     "https://github.com/libsdl-org/sdl2-compat"     main || { echo "Failed to clone SDL2_compat"     >&2; exit 1; }

#echo Updating SDL_shadercross submodules
#call git -C source\SDL_shadercross submodule update --init --recursive --quiet || exit /b 1
#call git -C source\SDL_shadercross submodule foreach git reset --quiet --hard HEAD || exit /b 1

#
# Apply patches
#

echo Applying patches
#git -C "$SOURCE/SDL_mixer" apply -p1 "$SCRIPT_DIR/patches/SDL_mixer.patch"
git -C "$SOURCE/SDL_ttf" apply -p1 "$SCRIPT_DIR/patches/SDL_ttf.patch"
echo Applied patches

#
# Build Flags
#

CMAKE_COMMON_ARGS=(
  -Wno-dev
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release

  -DCMAKE_C_COMPILER="$CC"
  -DCMAKE_CXX_COMPILER="$CXX"
  -DCMAKE_OBJC_COMPILER="$OBJCC"
  -DCMAKE_OBJCXX_COMPILER="$OBJCXX"

  -DCMAKE_C_FLAGS="-fno-objc-msgsend-selector-stubs"
  -DCMAKE_CXX_FLAGS="-fno-objc-msgsend-selector-stubs"
  -DCMAKE_OBJC_FLAGS="-fno-objc-msgsend-selector-stubs"
  -DCMAKE_OBJCXX_FLAGS="-fno-objc-msgsend-selector-stubs"

  -DCMAKE_POLICY_DEFAULT_CMP0074=NEW
  -DCMAKE_POLICY_DEFAULT_CMP0092=NEW
  -DCMAKE_POLICY_DEFAULT_CMP0111=NEW
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  -DCMAKE_INSTALL_BUNDLEDIR="$BUILD/bin"
  -DCMAKE_INSTALL_FRAMEWORKDIR="$BUILD/Frameworks"
  -DCMAKE_FRAMEWORK=OFF

  -DCMAKE_SYSTEM_NAME="$TARGET_PLATFORM"
  -DCMAKE_SYSTEM_PROCESSOR="$IOS_ARCH"
  -DCMAKE_OSX_SYSROOT="$SDK"
  -DCMAKE_OSX_ARCHITECTURES="$IOS_ARCH"
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
  -DCMAKE_MACOSX_BUNDLE=OFF

  -DBUILD_SHARED_LIBS=OFF
  -DBUILD_STATIC_LIBS=ON
  -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON

  -DSDL3_ROOT="$OUTPUT"
  -DSDL3_DIR="$OUTPUT/lib/cmake/SDL3"

  -DCMAKE_INSTALL_PREFIX="$OUTPUT"
  -DCMAKE_PREFIX_PATH="$OUTPUT"

  -DMAIN_EXECUTABLE=OFF
)

#
# SDL
#

cmake \
	"${CMAKE_COMMON_ARGS[@]}" \
	-S "$SOURCE/SDL" \
	-B "$BUILD/SDL" \
	-DSDL_SHARED=OFF \
	-DSDL_STATIC=ON \
	-DSDL_TESTS=OFF \
	-DSDL_OPENGLES=ON \
	-DSDL_EXAMPLES=OFF
cmake \
    --build "$BUILD/SDL" \
    --parallel
cmake \
    --install "$BUILD/SDL"

#
# SDL_image
#

bash "$SOURCE/SDL_image/external/download.sh"
cmake \
	"${CMAKE_COMMON_ARGS[@]}" \
	-S "$SOURCE/SDL_image" \
	-B "$BUILD/SDL_image" \
	-DSDLIMAGE_STRICT=ON       \
	-DSDLIMAGE_DEPS_SHARED=OFF \
	-DSDLIMAGE_VENDORED=ON     \
	-DSDLIMAGE_WERROR=OFF      \
	-DSDLIMAGE_STRICT=ON       \
	-DSDLIMAGE_SAMPLES=OFF     \
	-DSDLIMAGE_TESTS=OFF       \
	-DSDLIMAGE_BACKEND_STB=OFF     \
	-DSDLIMAGE_BACKEND_WIC=OFF     \
	-DSDLIMAGE_BACKEND_IMAGEIO=ON  \
	-DWEBP_BUILD_WEBP_JS=OFF   \
	-DBROTLI_DISABLE_TESTS=ON  \
	-DSDLIMAGE_AVIF=OFF        \
	-DSDLIMAGE_BMP=ON          \
	-DSDLIMAGE_GIF=ON          \
	-DSDLIMAGE_JPG=ON          \
	-DSDLIMAGE_JXL=OFF         \
	-DSDLIMAGE_LBM=ON          \
	-DSDLIMAGE_PCX=ON          \
	-DSDLIMAGE_PNG=ON          \
	-DSDLIMAGE_PNG_LIBPNG=OFF  \
	-DSDLIMAGE_PNM=ON          \
	-DSDLIMAGE_QOI=ON          \
	-DSDLIMAGE_SVG=ON          \
	-DSDLIMAGE_TGA=ON          \
	-DSDLIMAGE_TIF=ON          \
	-Dtiff-framework=OFF       \
	-Dtiff-static=ON           \
	-DSDLIMAGE_WEBP=OFF        \
	-DSDLIMAGE_XCF=ON          \
	-DSDLIMAGE_XPM=ON          \
	-DSDLIMAGE_XV=ON           \
	-DSDLIMAGE_AVIF_SAVE=OFF   \
	-DSDLIMAGE_JPG_SAVE=OFF    \
	-DSDLIMAGE_PNG_SAVE=OFF
cmake \
    --build "$BUILD/SDL_image" \
    --parallel
cmake \
    --install "$BUILD/SDL_image"

#
# SDL_mixer
#

bash "$SOURCE/SDL_mixer/external/download.sh"
cmake \
	"${CMAKE_COMMON_ARGS[@]}" \
	-S "$SOURCE/SDL_mixer" \
	-B "$BUILD/SDL_mixer" \
	-DSDLMIXER_STRICT=ON            \
	-DSDLMIXER_DEPS_SHARED=OFF      \
	-DSDLMIXER_VENDORED=ON          \
	-DSDLMIXER_WERROR=OFF           \
	-DSDLMIXER_STRICT=ON            \
	-DSDLMIXER_TESTS=OFF            \
	-DSDLMIXER_EXAMPLES=OFF         \
	-DSDLMIXER_AIFF=ON              \
	-DSDLMIXER_WAVE=ON              \
	-DSDLMIXER_VOC=ON               \
	-DSDLMIXER_AU=ON                \
	-DSDLMIXER_FLAC_LIBFLAC=OFF     \
	-DSDLMIXER_FLAC_DRFLAC=ON       \
	-DSDLMIXER_GME=OFF              \
	-DSDLMIXER_GME_SHARED=OFF       \
	-DSDLMIXER_MOD_XMP=OFF          \
	-DSDLMIXER_MP3_DRMP3=ON         \
	-DSDLMIXER_MP3_MPG123=OFF       \
	-DSDLMIXER_MIDI=OFF             \
	-DSDLMIXER_MIDI_FLUIDSYNTH=OFF  \
	-DSDLMIXER_MIDI_TIMIDITY=OFF    \
	-DSDLMIXER_OPUS=ON              \
	-DSDLMIXER_VORBIS_STB=ON        \
	-DSDLMIXER_VORBIS_VORBISFILE=OFF \
	-DSDLMIXER_WAVPACK=OFF
cmake \
    --build "$BUILD/SDL_mixer" \
    --parallel
cmake \
    --install "$BUILD/SDL_mixer"

#
# SDL_ttf
#

bash "$SOURCE/SDL_ttf/external/download.sh"
cmake \
	"${CMAKE_COMMON_ARGS[@]}" \
	-S "$SOURCE/SDL_ttf" \
	-B "$BUILD/SDL_ttf" \
	-DSDLTTF_STRICT=ON                        \
	-DSDLTTF_VENDORED=ON                      \
	-DSDLTTF_WERROR=OFF                       \
	-DSDLTTF_SAMPLES=OFF                      \
	-DSDLTTF_FREETYPE=ON                      \
	-DSDLTTF_HARFBUZZ=ON                      \
	-DSDLTTF_PLUTOSVG=OFF
#	-DCMAKE_C_FLAGS="-DPLUTOSVG_BUILD_STATIC"
cmake \
    --build "$BUILD/SDL_ttf" \
    --parallel
cmake \
    --install "$BUILD/SDL_ttf"
: '
rem
rem SDL_rtf
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL_rtf              ^
  -B %BUILD%\SDL_rtf               ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDLTTF_STRICT=ON              ^
  -D SDLRTF_WERROR=OFF             ^
  -D SDLRTF_SAMPLES=OFF            ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_rtf install || exit /b 1

rem
rem SDL_net
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL_net              ^
  -B %BUILD%\SDL_net               ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDLNET_WERROR=OFF             ^
  -D SDLNET_SAMPLES=OFF            ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_net install || exit /b 1

rem
rem SDL_sound
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL_sound            ^
  -B %BUILD%\SDL_sound             ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D SDLSOUND_BUILD_STATIC=OFF     ^
  -D SDLSOUND_BUILD_SHARED=ON      ^
  -D SDLSOUND_BUILD_TEST=OFF       ^
  -D SDLSOUND_BUILD_DOCS=OFF       ^
  -D SDLSOUND_DECODER_WAV=ON       ^
  -D SDLSOUND_DECODER_AIFF=ON      ^
  -D SDLSOUND_DECODER_AU=ON        ^
  -D SDLSOUND_DECODER_VOC=ON       ^
  -D SDLSOUND_DECODER_FLAC=ON      ^
  -D SDLSOUND_DECODER_VORBIS=ON    ^
  -D SDLSOUND_DECODER_RAW=ON       ^
  -D SDLSOUND_DECODER_SHN=ON       ^
  -D SDLSOUND_DECODER_MODPLUG=ON   ^
  -D SDLSOUND_DECODER_MP3=ON       ^
  -D SDLSOUND_DECODER_MIDI=ON      ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_sound install || exit /b 1

rem
rem SDL_shadercross
rem

if "%HOST_ARCH%" neq "%TARGET_PLATFORM%" (
  setlocal
  call "!VS!\Common7\Tools\VsDevCmd.bat" -arch=!HOST_ARCH! -host_arch=!HOST_ARCH! -startdir=none -no_logo || exit /b 1

  cmake.exe                                                          ^
    -G Ninja                                                         ^
    -S %SOURCE%\SDL_shadercross\external\DirectXShaderCompiler       ^
    -B %BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native ^
    -D CMAKE_BUILD_TYPE=Release                                      ^
    -D BUILD_SHARED_LIBS=OFF                                         ^
    -D LLVM_TARGETS_TO_BUILD=None                                    ^
    -D LLVM_ENABLE_WARNINGS=OFF                                      ^
    -D LLVM_ENABLE_EH=ON                                             ^
    -D LLVM_ENABLE_RTTI=ON                                           ^
    || exit /b 1
  ninja.exe -C %BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native llvm-tblgen clang-tblgen || exit /b 1

  endlocal
  set PATH=%BUILD%\SDL_shadercross\external\DirectXShaderCompiler-native\bin;!PATH!
) else (
  set PATH=%BUILD%\SDL_shadercross\external\DirectXShaderCompiler\bin;!PATH!
)

cmake.exe %CMAKE_COMMON_ARGS%             ^
  -S %SOURCE%\SDL_shadercross             ^
  -B %BUILD%\SDL_shadercross              ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT%        ^
  -D CMAKE_PREFIX_PATH=%DEPEND%           ^
  -D SDL3_ROOT=%OUTPUT%                   ^
  -D SDLSHADERCROSS_CLI=ON                ^
  -D SDLSHADERCROSS_VENDORED=ON           ^
  -D SDLSHADERCROSS_SHARED=ON             ^
  -D SDLSHADERCROSS_STATIC=OFF            ^
  -D SDLSHADERCROSS_SPIRVCROSS_SHARED=OFF ^
  -D SDLSHADERCROSS_INSTALL=ON            ^
  -D SDLSHADERCROSS_INSTALL_CPACK=OFF     ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL_shadercross install || exit /b 1

rem
rem SDL2_compat
rem

cmake.exe %CMAKE_COMMON_ARGS%      ^
  -S %SOURCE%\SDL2_compat          ^
  -B %BUILD%\SDL2_compat           ^
  -D CMAKE_INSTALL_PREFIX=%OUTPUT% ^
  -D CMAKE_PREFIX_PATH=%DEPEND%    ^
  -D BUILD_SHARED_LIBS=ON          ^
  -D SDL3_ROOT=%OUTPUT%            ^
  -D SDL2COMPAT_TESTS=OFF          ^
  -D SDL2COMPAT_STATIC=OFF         ^
  || exit /b 1
ninja.exe -C %BUILD%\SDL2_compat install || exit /b 1

set CL=

pushd %BUILD%\SDL2_compat
del SDL2main.lib
cl.exe -c -MT -O2 -Zl -DDLL_EXPORT -DNDEBUG -DWIN32 -I%OUTPUT%\include\SDL2 %SOURCE%\SDL2_compat\src\SDLmain\windows\SDL_windows_main.c || exit /b 1
lib.exe -nologo -out:SDL2main.lib SDL_windows_main.obj || exit /b 1
move /y SDL2main.lib %OUTPUT%\lib\
popd
'

#
# Collect Commit Hashes
#

SDL_COMMIT="$(git -C "$SOURCE/SDL" rev-parse HEAD)"
SDL_IMAGE_COMMIT="$(git -C "$SOURCE/SDL_image" rev-parse HEAD)"
SDL_MIXER_COMMIT="$(git -C "$SOURCE/SDL_mixer" rev-parse HEAD)"
SDL_TTF_COMMIT="$(git -C "$SOURCE/SDL_ttf" rev-parse HEAD)"
#SDL_RTF_COMMIT="$(git -C "$SOURCE/SDL_rtf" rev-parse HEAD)"
#SDL_NET_COMMIT="$(git -C "$SOURCE/SDL_net" rev-parse HEAD)"
#SDL_SOUND_COMMIT="$(git -C "$SOURCE/SDL_sound" rev-parse HEAD)"
#SDL_SHADERCROSS_COMMIT="$(git -C "$SOURCE/SDL_shadercross" rev-parse HEAD)"
#SDL2_COMPAT_COMMIT="$(git -C "$SOURCE/SDL2_compat" rev-parse HEAD)"

{
    printf "SDL             %s\n" "$SDL_COMMIT"
    printf "SDL_image       %s\n" "$SDL_IMAGE_COMMIT"
    printf "SDL_mixer       %s\n" "$SDL_MIXER_COMMIT"
    printf "SDL_ttf         %s\n" "$SDL_TTF_COMMIT"
    #printf "SDL_rtf         %s\n" "$SDL_RTF_COMMIT"
    #printf "SDL_net         %s\n" "$SDL_NET_COMMIT"
    #printf "SDL_sound       %s\n" "$SDL_SOUND_COMMIT"
    #printf "SDL_shadercross %s\n" "$SDL_SHADERCROSS_COMMIT"
    #printf "SDL2_compat     %s\n" "$SDL2_COMPAT_COMMIT"
} > "$OUTPUT/commits.txt"

echo "Coalescing libraries"
libtool -static -o "$OUTPUT/libSDL3_monolithic.a" "$OUTPUT/lib"/*.a "$OUTPUT/compiler-rt/libclang_rt.ios.a"
echo "Coalesced libraries"

#
# GitHub Actions
#

if [ -n "$GITHUB_WORKFLOW" ]; then
	OUTPUT_DATE=$(date +"%Y-%m-%d")

    rm -f "$OUTPUT/bin/sdl2-config" 2>/dev/null
    rm -f "$OUTPUT"/lib/libSDL3_test.* "$OUTPUT"/lib/libSDL2_test.* "$OUTPUT/lib/SDL2main.pdb" 2>/dev/null
    rm -f "$OUTPUT"/include/SDL3/SDL_test*.h "$OUTPUT"/include/SDL2/SDL_test*.h 2>/dev/null

    rm -rf "$OUTPUT/cmake" "$OUTPUT/lib/pkgconfig" "$OUTPUT/licenses" "$OUTPUT/share" "$OUTPUT/optional" 2>/dev/null

    echo "Creating SDL3-$TARGET_PLATFORM-$OUTPUT_DATE.zip"

    tar -cavf "SDL3-$TARGET_PLATFORM-$OUTPUT_DATE.zip" "SDL3-$TARGET_PLATFORM" || return 1

    {
        echo "OUTPUT_DATE=$OUTPUT_DATE"
        echo "SDL_COMMIT=$SDL_COMMIT"
        echo "SDL_IMAGE_COMMIT=$SDL_IMAGE_COMMIT"
        echo "SDL_MIXER_COMMIT=$SDL_MIXER_COMMIT"
        echo "SDL_TTF_COMMIT=$SDL_TTF_COMMIT"
        #echo "SDL_RTF_COMMIT=$SDL_RTF_COMMIT"
        #echo "SDL_NET_COMMIT=$SDL_NET_COMMIT"
        #echo "SDL_SOUND_COMMIT=$SDL_SOUND_COMMIT"
        #echo "SDL_SHADERCROSS_COMMIT=$SDL_SHADERCROSS_COMMIT"
        #echo "SDL2_COMPAT_COMMIT=$SDL2_COMPAT_COMMIT"
    } >> "$GITHUB_OUTPUT"

fi

#
# done!
#
