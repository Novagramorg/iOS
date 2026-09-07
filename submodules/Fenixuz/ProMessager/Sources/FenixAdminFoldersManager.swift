import Foundation
import UIKit
import Postbox
import TelegramCore
import AccountContext
import SwiftSignalKit

// Fenixuz Feature #47: auto-managed folders for the groups/channels the user owns or admins.
// Enabled by "fenix_admin_folders" in the "pro_messager" UserDefaults suite.
//
// When enabled, up to 4 REAL Telegram folders (cloud dialog filters) are created and kept in
// sync: 👑 owner groups, 👑 owner channels, 🔑 admin (non-owner) groups, 🔑 admin channels.
// Real folders on purpose — every standard folder surface (tabs, edit screen, reorder, tags)
// keeps working with zero extra UI code, and the folders follow the account to other devices.
//
// Sync rules:
//   - only membership (includePeers) is managed; a user's rename/edit of a managed folder sticks
//   - a category with no matching chats gets no folder; the folder is removed when it empties
//   - a managed folder the user deletes by hand stays deleted (tombstone) until the toggle
//     is turned off and on again — re-enabling is explicit consent to recreate everything
//   - folders left over from a reinstall are adopted by title instead of duplicated
//   - turning the toggle off deletes only the folders this feature created, on every account
public final class FenixAdminFoldersManager {

    private static let suiteName = "pro_messager"
    private static let enabledKey = "fenix_admin_folders"
    private static let mapKeyPrefix = "fenix_admin_folders_map_"
    // Map value marking "the user deleted this folder by hand — do not recreate".
    private static let tombstoneId: Int32 = -1

    private enum Category: String, CaseIterable {
        case ownerGroups
        case ownerChannels
        case adminGroups
        case adminChannels

        // Standard emoticons so the folder edit screen shows the proper group/channel icon.
        var emoticon: String {
            switch self {
            case .ownerGroups, .adminGroups: return "👥"
            case .ownerChannels, .adminChannels: return "📢"
            }
        }

        // Folder titles must stay within Telegram's 12-character folder name limit,
        // emoji included — every variant below is 11 UTF-16 units or fewer.
        func title(langCode: String) -> String {
            switch self {
            case .ownerGroups:
                switch langCode {
                case "uz": return "👑 Guruhlar"
                case "ru": return "👑 Группы"
                default: return "👑 Groups"
                }
            case .ownerChannels:
                switch langCode {
                case "uz": return "👑 Kanallar"
                case "ru": return "👑 Каналы"
                default: return "👑 Channels"
                }
            case .adminGroups:
                switch langCode {
                case "uz": return "🔑 Guruhlar"
                case "ru": return "🔑 Группы"
                default: return "🔑 Groups"
                }
            case .adminChannels:
                switch langCode {
                case "uz": return "🔑 Kanallar"
                case "ru": return "🔑 Каналы"
                default: return "🔑 Channels"
                }
            }
        }

        // Every localized spelling — used to adopt a folder left over from a previous
        // install (or created by this feature on another device) instead of duplicating it.
        var allKnownTitles: [String] {
            return ["en", "uz", "ru"].map { self.title(langCode: $0) }
        }
    }

    public static var isEnabled: Bool {
        return UserDefaults(suiteName: suiteName)?.bool(forKey: enabledKey) == true
    }

    // MARK: - Per-account category → filterId map

    private static func mapKey(accountPeerId: PeerId) -> String {
        return "\(mapKeyPrefix)\(accountPeerId.toInt64())"
    }

    private static func storedMap(accountPeerId: PeerId) -> [String: Int32] {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let raw = defaults.dictionary(forKey: mapKey(accountPeerId: accountPeerId)) as? [String: NSNumber]
        else {
            return [:]
        }
        return raw.mapValues { $0.int32Value }
    }

    private static func storeMap(_ map: [String: Int32], accountPeerId: PeerId) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let storeKey = mapKey(accountPeerId: accountPeerId)
        if map.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(map.mapValues { NSNumber(value: $0) }, forKey: storeKey)
        }
    }

    // MARK: - Global monitor (launch + account switch + app foreground)

    private static var monitorActive = false
    private static weak var monitorContext: AccountContext?
    private static var foregroundObserverInstalled = false
    private static var syncInFlight = false
    private static var lastSyncAt: [Int64: Double] = [:]
    private static let minSyncInterval: Double = 30.0

    /// Start (or re-point) the folder sync for the given authorized account.
    public static func startGlobalMonitor(context: AccountContext) {
        guard isEnabled else { return }
        installForegroundObserverIfNeeded()
        if monitorActive && monitorContext === context { return }

        monitorContext = context
        monitorActive = true
        // Small delay so the sync never competes with launch work.
        Queue.mainQueue().after(1.5, {
            guard monitorActive, isEnabled, let context = monitorContext else { return }
            sync(context: context, force: false, completion: nil)
        })
    }

    /// Stop the sync (toggle turned off, or no account is active).
    public static func stopGlobalMonitor() {
        monitorActive = false
        monitorContext = nil
    }

    private static func installForegroundObserverIfNeeded() {
        guard !foregroundObserverInstalled else { return }
        foregroundObserverInstalled = true
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main, using: { _ in
            guard monitorActive, isEnabled, let context = monitorContext else { return }
            sync(context: context, force: false, completion: nil)
        })
    }

    // MARK: - Toggle entry points (settings screen)

    public enum EnableOutcome {
        // `created` counts brand-new folders; adopted/refreshed ones only raise `total`.
        case foldersReady(created: Int, total: Int)
        // The user is not an owner/admin anywhere yet — nothing to show, folders appear later.
        case nothingToManage
    }

    public static func enable(context: AccountContext, completion: @escaping (EnableOutcome) -> Void) {
        UserDefaults(suiteName: suiteName)?.set(true, forKey: enabledKey)
        // Re-enabling is explicit consent to create all folders again — tombstones die here.
        let accountPeerId = context.account.peerId
        let cleanedMap = storedMap(accountPeerId: accountPeerId).filter { $0.value != tombstoneId }
        storeMap(cleanedMap, accountPeerId: accountPeerId)

        startGlobalMonitor(context: context)
        sync(context: context, force: true, completion: { created, total in
            if total > 0 {
                completion(.foldersReady(created: created, total: total))
            } else {
                completion(.nothingToManage)
            }
        })
    }

    public static func disable(context: AccountContext) {
        UserDefaults(suiteName: suiteName)?.set(false, forKey: enabledKey)
        stopGlobalMonitor()
        // Remove the managed folders on every account that is currently available. Each
        // removal captures its ids before its map is cleared, so the sweep below is safe.
        _ = (context.sharedContext.activeAccountContexts
        |> take(1)
        |> deliverOnMainQueue).start(next: { _, accounts, _ in
            for (_, accountContext, _) in accounts {
                removeManagedFolders(context: accountContext)
            }
            // Accounts outside the working set can't be edited from here — drop their maps
            // too; if they re-enable later, adoption-by-title reclaims the old folders.
            if let defaults = UserDefaults(suiteName: suiteName) {
                for storeKey in defaults.dictionaryRepresentation().keys where storeKey.hasPrefix(mapKeyPrefix) {
                    defaults.removeObject(forKey: storeKey)
                }
            }
        })
    }

    private static func removeManagedFolders(context: AccountContext) {
        let accountPeerId = context.account.peerId
        let managedIds = Set(storedMap(accountPeerId: accountPeerId).values.filter { $0 != tombstoneId })
        storeMap([:], accountPeerId: accountPeerId)
        guard !managedIds.isEmpty else { return }
        _ = context.engine.peers.updateChatListFiltersInteractively({ filters in
            return filters.filter { filter in
                if case let .filter(id, _, _, _) = filter {
                    return !managedIds.contains(id)
                }
                return true
            }
        }).start()
    }

    // MARK: - Sync

    private static func sync(context: AccountContext, force: Bool, completion: ((Int, Int) -> Void)?) {
        let accountPeerId = context.account.peerId
        let accountKey = accountPeerId.toInt64()
        let now = CFAbsoluteTimeGetCurrent()
        if !force {
            if syncInFlight { return }
            if let last = lastSyncAt[accountKey], now - last < minSyncInterval { return }
        }
        syncInFlight = true
        lastSyncAt[accountKey] = now

        _ = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.messages.chatList(group: .root, count: 1000) |> take(1),
            context.engine.messages.chatList(group: .archive, count: 500) |> take(1),
            context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: accountPeerId),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: false),
                TelegramEngine.EngineData.Item.Configuration.UserLimits(isPremium: true)
            )
        ).start(next: { rootList, archiveList, configuration in
            let (accountPeer, freeLimits, premiumLimits) = configuration
            let isPremium = accountPeer?.isPremium ?? false
            let maxChatsPerFolder = Int(isPremium ? premiumLimits.maxFolderChatsCount : freeLimits.maxFolderChatsCount)

            // Newest chats first, so the per-folder cap keeps the active ones when truncating.
            var byCategory: [Category: [PeerId]] = [:]
            for item in (archiveList.items + rootList.items).reversed() {
                guard let peer = item.renderedPeer.chatMainPeer else { continue }
                guard let category = classify(peer: peer._asPeer()) else { continue }
                byCategory[category, default: []].append(peer.id)
            }

            let langCode = context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
            applyToFilters(context: context, accountPeerId: accountPeerId, byCategory: byCategory, maxChats: maxChatsPerFolder, langCode: langCode, completion: completion)
        })
    }

    private static func classify(peer: Peer) -> Category? {
        if let channel = peer as? TelegramChannel {
            guard case .member = channel.participationStatus else { return nil }
            let isOwner = channel.flags.contains(.isCreator)
            guard isOwner || channel.adminRights != nil else { return nil }
            switch channel.info {
            case .broadcast:
                return isOwner ? .ownerChannels : .adminChannels
            case .group:
                return isOwner ? .ownerGroups : .adminGroups
            }
        } else if let group = peer as? TelegramGroup {
            if group.flags.contains(.deactivated) {
                return nil
            }
            guard case .Member = group.membership else { return nil }
            switch group.role {
            case .creator:
                return .ownerGroups
            case .admin:
                return .adminGroups
            case .member:
                return nil
            }
        }
        return nil
    }

    private static func applyToFilters(context: AccountContext, accountPeerId: PeerId, byCategory: [Category: [PeerId]], maxChats: Int, langCode: String, completion: ((Int, Int) -> Void)?) {
        let createdCount = Atomic<Int>(value: 0)
        let managedCount = Atomic<Int>(value: 0)

        _ = (context.engine.peers.updateChatListFiltersInteractively { filters in
            var result = filters
            var map = storedMap(accountPeerId: accountPeerId)
            var created = 0

            for category in Category.allCases {
                let peers = Array((byCategory[category] ?? []).prefix(maxChats))

                if let mappedId = map[category.rawValue], mappedId == tombstoneId {
                    continue
                }

                if let mappedId = map[category.rawValue] {
                    if let index = result.firstIndex(where: { $0.id == mappedId }) {
                        if peers.isEmpty {
                            // No longer admin anywhere in this category — an empty folder
                            // is invalid server-side, so drop it (recreated when needed).
                            result.remove(at: index)
                            map.removeValue(forKey: category.rawValue)
                        } else if case let .filter(id, title, emoticon, data) = result[index] {
                            var updatedData = data
                            updatedData.includePeers.setPeers(peers)
                            updatedData.excludePeers.removeAll(where: { peers.contains($0) })
                            if updatedData != data {
                                result[index] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                            }
                        }
                    } else {
                        // The folder we managed is gone — the user deleted it. Respect that.
                        map[category.rawValue] = tombstoneId
                    }
                    continue
                }

                guard !peers.isEmpty else { continue }

                // Adopt a leftover folder with one of our titles (not claimed by another
                // category) instead of creating a duplicate.
                let claimedIds = Set(map.values)
                if let index = result.firstIndex(where: { filter in
                    if case let .filter(id, title, _, _) = filter {
                        return !claimedIds.contains(id) && category.allKnownTitles.contains(title.text)
                    }
                    return false
                }), case let .filter(id, title, emoticon, data) = result[index] {
                    var updatedData = data
                    updatedData.includePeers.setPeers(peers)
                    updatedData.excludePeers.removeAll(where: { peers.contains($0) })
                    result[index] = .filter(id: id, title: title, emoticon: emoticon, data: updatedData)
                    map[category.rawValue] = id
                    continue
                }

                var includePeers = ChatListFilterIncludePeers()
                includePeers.setPeers(peers)
                let data = ChatListFilterData(
                    isShared: false,
                    hasSharedLinks: false,
                    categories: [],
                    excludeMuted: false,
                    excludeRead: false,
                    excludeArchived: false,
                    includePeers: includePeers,
                    excludePeers: [],
                    color: nil
                )
                let newId = context.engine.peers.generateNewChatListFilterId(filters: result)
                result.append(.filter(
                    id: newId,
                    title: ChatFolderTitle(text: category.title(langCode: langCode), entities: [], enableAnimations: true),
                    emoticon: category.emoticon,
                    data: data
                ))
                map[category.rawValue] = newId
                created += 1
            }

            storeMap(map, accountPeerId: accountPeerId)
            _ = createdCount.swap(created)
            _ = managedCount.swap(map.values.filter({ $0 != tombstoneId }).count)
            return result
        }
        |> deliverOnMainQueue).start(next: { _ in
            syncInFlight = false
            completion?(createdCount.with { $0 }, managedCount.with { $0 })
        })
    }
}

// MARK: - Strings (kept here to avoid parallel-edit hazard on the shared Localization module)

enum FenixAdminFoldersStrings {
    static func toggleTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Admin papkalar"
        case "ru": return "Папки админа"
        default:   return "Admin Folders"
        }
    }

    static func toggleSubtitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Siz ega (👑) yoki admin (🔑) bo'lgan guruh va kanallarni 4 ta avtomatik papkaga ajratib beradi. Huquqlaringiz o'zgarsa papkalar o'z-o'zidan yangilanadi; o'chirilganda papkalar olib tashlanadi."
        case "ru": return "Раскладывает группы и каналы, где вы владелец (👑) или админ (🔑), по 4 автоматическим папкам. Папки обновляются сами при изменении ваших прав; при отключении они удаляются."
        default:   return "Sorts the groups and channels you own (👑) or admin (🔑) into 4 automatic folders. They keep updating as your rights change; turning this off removes them."
        }
    }

    static func createdAlert(count: Int, langCode: String) -> String {
        switch langCode {
        case "uz": return "\(count) ta papka yaratildi. Admin huquqlaringiz o'zgarganda papkalar avtomatik yangilanib boradi."
        case "ru": return "Создано папок: \(count). Они будут обновляться автоматически при изменении ваших прав."
        default:   return count == 1 ? "1 folder created. It will keep updating automatically as your admin rights change." : "\(count) folders created. They will keep updating automatically as your admin rights change."
        }
    }

    static func upToDateAlert(langCode: String) -> String {
        switch langCode {
        case "uz": return "Papkalaringiz allaqachon mavjud — ro'yxatlari yangilab chiqildi."
        case "ru": return "Папки уже существуют — их содержимое обновлено."
        default:   return "Your folders already exist — their contents have been refreshed."
        }
    }

    static func emptyAlert(langCode: String) -> String {
        switch langCode {
        case "uz": return "Siz hozircha hech bir guruh yoki kanalda ega yoki admin emassiz. Admin bo'lganingizda papkalar avtomatik paydo bo'ladi."
        case "ru": return "Пока вы не владелец и не админ ни в одной группе или канале. Папки появятся автоматически, как только вы ими станете."
        default:   return "You are not an owner or admin of any group or channel yet. The folders will appear automatically once you become one."
        }
    }
}
