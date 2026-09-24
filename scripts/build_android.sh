#!/bin/bash
set -e

echo "=== Building Rust Native Library for Android ==="

export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Library/Android/sdk/ndk/27.0.12077973}"
if [ ! -d "$ANDROID_NDK_HOME" ]; then
    export ANDROID_NDK_HOME=$(ls -d $HOME/Library/Android/sdk/ndk/* | tail -n 1)
fi

echo "Using NDK at: $ANDROID_NDK_HOME"

JNI_DIR="../android/app/src/main/jniLibs"

cd rust

cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o "$JNI_DIR" build --release

echo "=== Android jniLibs successfully built! ==="
ls -la "$JNI_DIR"/*/*.so
