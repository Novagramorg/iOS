import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import PresentationDataUtils
import NovagramLocalization

// Public helper for Feature #19 (add recommended folders) and the first-launch prompt.
// Folder creation is separate from the Settings UI so ApplicationContext can call it too.

public enum NovagramRecommendedFolders {

    // Creates up to 4 recommended folders if not already present (deduped by title).
    // Completion is called on the main queue with true when at least one folder was added.
    public static func addIfNeeded(context: AccountContext, completion: ((Bool) -> Void)? = nil) {
        _ = (context.engine.peers.currentChatListFilters()
        |> take(1)
        |> deliverOnMainQueue).start(next: { filters in
            let langCode = NovagramL10n.languageKey(for: context.sharedContext.currentPresentationData.with { $0 }.strings)
            let existingTitles = Set(filters.compactMap { filter -> String? in
                if case let .filter(_, title, _, _) = filter { return title.text } else { return nil }
            })

            // Definitions for the 4 standard folders
            struct FolderSpec {
                let name: String
                let emoticon: String
                let categories: ChatListFilterPeerCategories
                let excludeRead: Bool
            }
            let specs: [FolderSpec] = [
                FolderSpec(name: NovagramFeaturesStrings.folderNamePersonal(langCode: langCode),
                           emoticon: "👤", categories: .contacts, excludeRead: false),
                FolderSpec(name: NovagramFeaturesStrings.folderNameUnread(langCode: langCode),
                           emoticon: "📥", categories: .all, excludeRead: true),
                FolderSpec(name: NovagramFeaturesStrings.folderNameChannels(langCode: langCode),
                           emoticon: "📢", categories: .channels, excludeRead: false),
                FolderSpec(name: NovagramFeaturesStrings.folderNameBots(langCode: langCode),
                           emoticon: "🤖", categories: .bots, excludeRead: false)
            ]
            let toAdd = specs.filter { !existingTitles.contains($0.name) }
            guard !toAdd.isEmpty else {
                completion?(false)
                return
            }

            _ = (context.engine.peers.updateChatListFiltersInteractively { current in
                var result = current
                for spec in toAdd {
                    let newId = context.engine.peers.generateNewChatListFilterId(filters: result)
                    let data = ChatListFilterData(
                        isShared: false,
                        hasSharedLinks: false,
                        categories: spec.categories,
                        excludeMuted: false,
                        excludeRead: spec.excludeRead,
                        excludeArchived: false,
                        includePeers: ChatListFilterIncludePeers(),
                        excludePeers: [],
                        color: nil
                    )
                    result.append(.filter(
                        id: newId,
                        title: ChatFolderTitle(text: spec.name, entities: [], enableAnimations: true),
                        emoticon: spec.emoticon,
                        data: data
                    ))
                }
                return result
            } |> deliverOnMainQueue).start(next: { _ in
                completion?(true)
            })
        })
    }

    // The "Add folders?" prompt is off by default. Novagram Settings has a switch to turn it on.
    private static let promptEnabledKey = "fenix_features_folders_prompt_enabled"

    public static var isFirstLaunchPromptEnabled: Bool {
        get { return UserDefaults(suiteName: "pro_messager")?.bool(forKey: promptEnabledKey) ?? false }
        set { UserDefaults(suiteName: "pro_messager")?.set(newValue, forKey: promptEnabledKey) }
    }

    // One-time first-launch prompt — fires exactly once, gated on "fenix_features_firstrun_done".
    // Called from ApplicationContext.swift after addRootControllers.
    public static func presentFirstLaunchPromptIfNeeded(context: AccountContext, rootController: NavigationController) {
        // Stays silent until the user turns the prompt on in Novagram Settings.
        // The firstrun flag is not used up here, so turning it on later still shows the prompt once.
        guard isFirstLaunchPromptEnabled else { return }
        let key = "fenix_features_firstrun_done"
        let ud = UserDefaults(suiteName: "pro_messager")
        guard !(ud?.bool(forKey: key) ?? false) else { return }
        ud?.set(true, forKey: key)

        // Delay 2.5s so the Tips/UpdateCheck screens (at 1.0s) don't compete with this prompt.
        Queue.mainQueue().after(2.5) {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let langCode = NovagramL10n.languageKey(for: presentationData.strings)
            let alert = textAlertController(
                context: context,
                title: NovagramFeaturesStrings.addFoldersAlertTitle(langCode: langCode),
                text: NovagramFeaturesStrings.addFoldersAlertText(langCode: langCode),
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: NovagramFeaturesStrings.addFoldersAlertConfirm(langCode: langCode), action: {
                        addIfNeeded(context: context)
                    })
                ],
                actionLayout: .horizontal
            )
            (rootController.viewControllers.last as? ViewController)?.present(alert, in: .window(.root))
        }
    }
}
