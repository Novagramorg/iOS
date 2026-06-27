import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import PresentationDataUtils

// Public helper for Feature #19 (add recommended folders) and the first-launch prompt.
// Folder creation is separate from the Settings UI so ApplicationContext can call it too.

public enum FenixRecommendedFolders {

    // Creates up to 4 recommended folders if not already present (deduped by title).
    // Completion is called on the main queue with true when at least one folder was added.
    public static func addIfNeeded(context: AccountContext, completion: ((Bool) -> Void)? = nil) {
        _ = (context.engine.peers.currentChatListFilters()
        |> take(1)
        |> deliverOnMainQueue).start(next: { filters in
            let langCode = context.sharedContext.currentPresentationData.with { $0 }.strings.primaryComponent.languageCode
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
                FolderSpec(name: FenixFeaturesStrings.folderNamePersonal(langCode: langCode),
                           emoticon: "👤", categories: .contacts, excludeRead: false),
                FolderSpec(name: FenixFeaturesStrings.folderNameUnread(langCode: langCode),
                           emoticon: "📥", categories: .all, excludeRead: true),
                FolderSpec(name: FenixFeaturesStrings.folderNameChannels(langCode: langCode),
                           emoticon: "📢", categories: .channels, excludeRead: false),
                FolderSpec(name: FenixFeaturesStrings.folderNameBots(langCode: langCode),
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

    // One-time first-launch prompt — fires exactly once, gated on "fenix_features_firstrun_done".
    // Called from ApplicationContext.swift after addRootControllers.
    public static func presentFirstLaunchPromptIfNeeded(context: AccountContext, rootController: NavigationController) {
        let key = "fenix_features_firstrun_done"
        let ud = UserDefaults(suiteName: "pro_messager")
        guard !(ud?.bool(forKey: key) ?? false) else { return }
        ud?.set(true, forKey: key)

        // Delay 2.5s so the Tips/UpdateCheck screens (at 1.0s) don't compete with this prompt.
        Queue.mainQueue().after(2.5) {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let langCode = presentationData.strings.primaryComponent.languageCode
            let alert = textAlertController(
                context: context,
                title: FenixFeaturesStrings.addFoldersAlertTitle(langCode: langCode),
                text: FenixFeaturesStrings.addFoldersAlertText(langCode: langCode),
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: FenixFeaturesStrings.addFoldersAlertConfirm(langCode: langCode), action: {
                        addIfNeeded(context: context)
                    })
                ],
                actionLayout: .horizontal
            )
            (rootController.viewControllers.last as? ViewController)?.present(alert, in: .window(.root))
        }
    }
}
