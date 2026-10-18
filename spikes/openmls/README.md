# Spike: OpenMLS no Android

**Não é código de produção.** Gera evidência para a decisão D1. Relatório: [docs/decisoes/spike-openmls.md](../../docs/decisoes/spike-openmls.md).

```sh
# no PC
cargo test --release -- --nocapture --test-threads=1

# Android (requer NDK r30 e cargo-ndk)
export ANDROID_NDK_HOME=<sdk>/ndk/30.0.16248370
cargo ndk -P 24 -t arm64-v8a -t armeabi-v7a -t x86_64 build --release
cargo ndk -P 24 -t x86_64 test --release --no-run
adb push target/x86_64-linux-android/release/deps/spike-<hash> /data/local/tmp/spike
adb shell /data/local/tmp/spike --nocapture --test-threads=1
```

No Git Bash do Windows, exporte `MSYS_NO_PATHCONV=1` antes do `adb`.
