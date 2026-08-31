load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

wallet_engine_sources = [
    "wallet-engine/Cargo.lock",
    "wallet-engine/Cargo.toml",
    "wallet-engine/rust-toolchain.toml",
    "wallet-engine/uniffi.toml",
] + glob([
    "wallet-engine/crates/**",
    "wallet-engine/src/**",
    "wallet-engine/vendor/ton/**",
])

wallet_engine_swift_binding_sources = wallet_engine_sources + [
    "wallet-engine/bindgen/apple/Cargo.lock",
    "wallet-engine/bindgen/apple/Cargo.toml",
    "wallet-engine/xtask/Cargo.lock",
    "wallet-engine/xtask/Cargo.toml",
] + glob([
    "wallet-engine/bindgen/apple/src/**",
    "wallet-engine/xtask/src/**",
])

filegroup(
    name = "wallet_engine_sources",
    srcs = wallet_engine_sources,
)

filegroup(
    name = "wallet_engine_swift_binding_sources",
    srcs = wallet_engine_swift_binding_sources,
)

genrule(
    name = "wallet_engine_build",
    srcs = [":wallet_engine_sources"],
    outs = ["libwallet_engine.a"],
    cmd_bash = """
    set -euo pipefail

    case "$(TARGET_CPU)" in
        ios_arm64)
            RUST_TARGET="aarch64-apple-ios"
            ;;
        ios_sim_arm64)
            RUST_TARGET="aarch64-apple-ios-sim"
            ;;
        ios_x86_64)
            RUST_TARGET="x86_64-apple-ios"
            ;;
        darwin_arm64)
            RUST_TARGET="aarch64-apple-darwin"
            ;;
        darwin_x86_64)
            RUST_TARGET="x86_64-apple-darwin"
            ;;
        k8|x86_64)
            RUST_TARGET="x86_64-unknown-linux-gnu"
            ;;
        aarch64|arm64)
            RUST_TARGET="aarch64-unknown-linux-gnu"
            ;;
        *)
            echo "Unsupported wallet-engine architecture: $(TARGET_CPU)" >&2
            exit 1
            ;;
    esac

    if [ -n "$${CARGO:-}" ]; then
        CARGO_BIN="$$CARGO"
    elif command -v cargo >/dev/null 2>&1; then
        CARGO_BIN="$$(command -v cargo)"
    elif [ -x ~/.cargo/bin/cargo ]; then
        CARGO_BIN=~/.cargo/bin/cargo
    else
        echo "cargo was not found; install the Rust toolchain from wallet-engine/rust-toolchain.toml" >&2
        exit 1
    fi

    EXEC_ROOT="$$(pwd)"
    SOURCE_ROOT="$$EXEC_ROOT/third-party/wallet-engine/wallet-engine"
    CARGO_OUTPUT="$$EXEC_ROOT/$(RULEDIR)/cargo-$$RUST_TARGET"
    OUTPUT="$$EXEC_ROOT/$(location libwallet_engine.a)"

    rm -rf "$$CARGO_OUTPUT"
    mkdir -p "$$CARGO_OUTPUT"

    cd "$$SOURCE_ROOT"
    CARGO_TARGET_DIR="$$CARGO_OUTPUT" "$$CARGO_BIN" build \
        --package wallet-engine \
        --release \
        --locked \
        --target "$$RUST_TARGET"

    cp "$$CARGO_OUTPUT/$$RUST_TARGET/release/libwallet_engine.a" "$$OUTPUT"
    """,
    local = True,
    visibility = ["//visibility:public"],
)

genrule(
    name = "wallet_engine_swift_bindings",
    srcs = [":wallet_engine_swift_binding_sources"],
    outs = [
        "Generated/WalletEngineFFI.swift",
        "Generated/wallet_engineFFI.h",
    ],
    cmd_bash = """
    set -euo pipefail

    if [ -n "$${CARGO:-}" ]; then
        CARGO_BIN="$$CARGO"
    elif command -v cargo >/dev/null 2>&1; then
        CARGO_BIN="$$(command -v cargo)"
    elif [ -x ~/.cargo/bin/cargo ]; then
        CARGO_BIN=~/.cargo/bin/cargo
    else
        echo "cargo was not found; install the Rust toolchain from wallet-engine/rust-toolchain.toml" >&2
        exit 1
    fi

    EXEC_ROOT="$$(pwd)"
    UPSTREAM_ROOT="$$EXEC_ROOT/third-party/wallet-engine/wallet-engine"
    BUILD_ROOT="$$EXEC_ROOT/$(RULEDIR)/swift-bindings-build"
    SOURCE_ROOT="$$BUILD_ROOT/source"
    SWIFT_OUTPUT="$$EXEC_ROOT/$(location Generated/WalletEngineFFI.swift)"
    HEADER_OUTPUT="$$EXEC_ROOT/$(location Generated/wallet_engineFFI.h)"

    rm -rf "$$BUILD_ROOT"
    mkdir -p "$$SOURCE_ROOT/bindgen"

    cp "$$UPSTREAM_ROOT/Cargo.lock" "$$SOURCE_ROOT/"
    cp "$$UPSTREAM_ROOT/Cargo.toml" "$$SOURCE_ROOT/"
    cp "$$UPSTREAM_ROOT/rust-toolchain.toml" "$$SOURCE_ROOT/"
    cp "$$UPSTREAM_ROOT/uniffi.toml" "$$SOURCE_ROOT/"
    cp -R "$$UPSTREAM_ROOT/crates" "$$SOURCE_ROOT/"
    cp -R "$$UPSTREAM_ROOT/src" "$$SOURCE_ROOT/"
    cp -R "$$UPSTREAM_ROOT/vendor" "$$SOURCE_ROOT/"
    cp -R "$$UPSTREAM_ROOT/xtask" "$$SOURCE_ROOT/"
    cp -R "$$UPSTREAM_ROOT/bindgen/apple" "$$SOURCE_ROOT/bindgen/"

    cd "$$SOURCE_ROOT"
    CARGO="$$CARGO_BIN" "$$CARGO_BIN" run \
        --manifest-path xtask/Cargo.toml \
        --target-dir "$$BUILD_ROOT/xtask-target" \
        --locked \
        -- bindings swift

    cp "bindings/swift/Sources/WalletEngineFFI/WalletEngineFFI.swift" "$$SWIFT_OUTPUT"
    cp "bindings/swift/Sources/wallet_engineFFI/wallet_engineFFI.h" "$$HEADER_OUTPUT"
    """,
    local = True,
    visibility = ["//visibility:public"],
)

cc_library(
    name = "wallet_engine_archive",
    srcs = [":libwallet_engine.a"],
)

objc_library(
    name = "wallet_engine",
    deps = [":wallet_engine_archive"],
    sdk_frameworks = [
        "Foundation",
        "Security",
    ],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "wallet_engine_ffi",
    module_name = "wallet_engineFFI",
    enable_modules = True,
    hdrs = [":Generated/wallet_engineFFI.h"],
    deps = [":wallet_engine"],
)

swift_library(
    name = "WalletEngineFFI",
    module_name = "WalletEngineFFI",
    srcs = [":Generated/WalletEngineFFI.swift"],
    copts = [
        "-swift-version",
        "6",
        "-suppress-warnings",
    ],
    deps = [":wallet_engine_ffi"],
    visibility = ["//visibility:public"],
)
