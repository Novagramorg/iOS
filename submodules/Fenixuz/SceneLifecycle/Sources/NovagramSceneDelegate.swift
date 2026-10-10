import UIKit

// UIScene life cycle for Novagram.
//
// Apps built with the iOS 27 SDK must use the scene-based life cycle, otherwise UIKit stops the
// launch ("UIScene life cycle is required for apps built with this SDK"). Telegram still sets up
// its single window and all launch logic in the app delegate, so this delegate stays thin:
// it attaches that window to the scene once the scene connects, and forwards every scene
// callback to the matching app delegate method, which UIKit no longer calls on its own.
@objc(NovagramSceneDelegate)
public final class NovagramSceneDelegate: UIResponder, UIWindowSceneDelegate {
    public var window: UIWindow?

    private var appDelegate: UIApplicationDelegate? {
        return UIApplication.shared.delegate
    }

    public func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene, let appWindow = self.appDelegate?.window, let window = appWindow else {
            return
        }
        window.windowScene = windowScene
        self.window = window
        window.makeKeyAndVisible()

        // Launch payloads arrive here now instead of in the launch options.
        if !connectionOptions.urlContexts.isEmpty {
            self.scene(scene, openURLContexts: connectionOptions.urlContexts)
        }
        for userActivity in connectionOptions.userActivities {
            self.scene(scene, continue: userActivity)
        }
        if let shortcutItem = connectionOptions.shortcutItem {
            self.windowScene(windowScene, performActionFor: shortcutItem, completionHandler: { _ in })
        }
    }

    public func sceneWillEnterForeground(_ scene: UIScene) {
        self.appDelegate?.applicationWillEnterForeground?(UIApplication.shared)
    }

    public func sceneDidBecomeActive(_ scene: UIScene) {
        self.appDelegate?.applicationDidBecomeActive?(UIApplication.shared)
    }

    public func sceneWillResignActive(_ scene: UIScene) {
        self.appDelegate?.applicationWillResignActive?(UIApplication.shared)
    }

    public func sceneDidEnterBackground(_ scene: UIScene) {
        self.appDelegate?.applicationDidEnterBackground?(UIApplication.shared)
    }

    public func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            var options: [UIApplication.OpenURLOptionsKey: Any] = [.openInPlace: context.options.openInPlace]
            if let sourceApplication = context.options.sourceApplication {
                options[.sourceApplication] = sourceApplication
            }
            if let annotation = context.options.annotation {
                options[.annotation] = annotation
            }
            _ = self.appDelegate?.application?(UIApplication.shared, open: context.url, options: options)
        }
    }

    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        _ = self.appDelegate?.application?(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
    }

    public func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        guard let handler = self.appDelegate?.application(_:performActionFor:completionHandler:) else {
            completionHandler(false)
            return
        }
        handler(UIApplication.shared, shortcutItem, completionHandler)
    }

    // The window root view controller used to be the scene delegate only to return this value.
    @available(iOS 26.0, *)
    public func preferredWindowingControlStyle(for windowScene: UIWindowScene) -> UIWindowScene.WindowingControlStyle {
        return .minimal
    }
}
