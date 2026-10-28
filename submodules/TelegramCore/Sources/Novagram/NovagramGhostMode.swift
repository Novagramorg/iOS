import Foundation

// Novagram Ghost Mode — single source of truth for "do not signal read/seen/online" gate.
//
// Read at runtime (no caching) so toggling Ghost mode in Settings or via the navbar
// shortcut takes effect immediately for the next outgoing acknowledgement.
//
// This file is the ONLY new file we add to TelegramCore for Novagram. Keeping the
// gate in TelegramCore is unavoidable because the network requests it gates live
// here, and TelegramCore is a base module that cannot import the Novagram module
// (which sits above it in the dependency graph).
//
// All consumer sites use a 1-line guard:
//
//     if isNovagramGhostModeActive { return .complete() }
//
// Storage key is shared with the rest of the Novagram settings (UserDefaults suite
// "pro_messager", boolean key "is_ghost_mode_active"). The suite name is legacy and
// kept for storage continuity with existing user installs.
@inline(__always)
internal var isNovagramGhostModeActive: Bool {
    return UserDefaults(suiteName: "pro_messager")?.bool(forKey: "is_ghost_mode_active") ?? false
}
