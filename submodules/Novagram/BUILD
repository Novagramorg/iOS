# Build switches shared by the Novagram modules (see novagram_module.bzl).

# --define=novagram_sdk=binary: modules come from Prebuilt/ instead of their sources.
config_setting(
    name = "novagram_sdk_binary",
    define_values = {"novagram_sdk": "binary"},
    visibility = ["//visibility:public"],
)

config_setting(
    name = "ios_sim_arm64",
    values = {"cpu": "ios_sim_arm64"},
    visibility = ["//visibility:public"],
)
