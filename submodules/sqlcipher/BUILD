
load("@rules_cc//cc:objc_library.bzl", "objc_library")

# Xcode 26.5 SDK fix: sqlite3ext.h ni PUBLIC HEADER'dan chiqaramiz, chunki
# Apple iPhoneSimulator26.5.sdk ichida sqlite3ext.h ning yangi versiyasi bor
# (SQLite 3.50+, qo'shimcha fieldlar: txn_state, changes64, autovacuum_pages, ...).
# sqlcipher'ning eski sqlite3ext.h struct sqlite3_api_routines'i Apple'niki bilan
# konflikt qiladi → "is not present in definition of 'struct sqlite3_api_routines'".
# Sqlcipher'ning o'z .c source fayllari sqlite3ext.h ni amalgamation ichida
# inline qiladi (SQLITE_CORE=1 bilan), shuning uchun uni public qilish shart emas.
# Tashqi consumer'lar (TelegramCore va h.k.) faqat sqlite3.h va sqlite3session.h
# ni ishlatadi.
public_headers = glob([
    "PublicHeaders/**/*.h",
], exclude = ["PublicHeaders/**/sqlite3ext.h"])

private_headers = glob([
    "PublicHeaders/**/sqlite3ext.h",
])

objc_library(
    name = "sqlcipher",
    enable_modules = True,
    module_name = "sqlcipher",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ], exclude = public_headers + private_headers, allow_empty=True) + private_headers,
    hdrs = public_headers,
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-DSQLITE_HAS_CODEC=1",
        "-DSQLCIPHER_CRYPTO_CC=1",
        # Required since SQLCipher 4.6: sqlcipher.c #errors without these.
        "-DSQLITE_EXTRA_INIT=sqlcipher_extra_init",
        "-DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown",
        "-DSQLITE_THREADSAFE=1",
        "-DSQLITE_TEMP_STORE=2",
        "-DSQLITE_ENABLE_FTS5",
        "-DHAVE_USLEEP=1",
        "-DSQLITE_DEFAULT_MEMSTATUS=0",
        "-DSQLITE_OMIT_LOAD_EXTENSION",
        "-DSQLITE_OMIT_DECLTYPE",
        "-DSQLITE_OMIT_PROGRESS_CALLBACK",
        "-DSQLITE_OMIT_DEPRECATED",
        "-DNDEBUG=1",
        "-DSQLITE_MAX_MMAP_SIZE=0",
        "-Wno-all",
        "-Wno-#warnings",
        # sqlite3.c defines MIN/MAX itself; with modules on, Foundation pulls in
        # <sys/param.h>'s textually different MIN/MAX, and clang warns at every
        # use. The pristine amalgamation is kept unpatched (the 2021 copy had a
        # hand edit normalising these macros); suppress the warning instead.
        "-Wno-ambiguous-macro",
    ],
    sdk_frameworks = [
      "Foundation",
      "Security",
    ],
    visibility = [
        "//visibility:public",
    ],
)
