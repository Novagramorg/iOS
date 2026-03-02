import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import PresentationDataUtils

public final class AIChatbotTabController: ViewController {
    private let context: AccountContext
    private var chatController: ViewController?
    private let disposable = MetaDisposable()
    
    public init(context: AccountContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)
        
        self.tabBarItem.title = "AI"
        if #available(iOS 13.0, *) {
            self.tabBarItem.image = UIImage(systemName: "sparkles")
            self.tabBarItem.selectedImage = UIImage(systemName: "sparkles")
        } else {
            self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconBots")
            self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconBots")
        }
        
        // No navigation bar — the ChatController renders its own header
        self.displayNavigationBar = false
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    public override func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        self.view.backgroundColor = self.context.sharedContext.currentPresentationData.with { $0 }.theme.list.plainBackgroundColor
        
        let botUsername = "fenixuz_bot"
        
        self.disposable.set((self.context.engine.peers.resolvePeerByName(name: botUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            guard case let .result(result) = result else {
                return .complete()
            }
            return .single(result)
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] peer in
            guard let strongSelf = self, let peer = peer else { return }
            
            let chatController = strongSelf.context.sharedContext.makeChatController(
                context: strongSelf.context,
                chatLocation: .peer(id: peer.id),
                subject: nil,
                botStart: nil,
                mode: .standard(.default),
                params: nil
            )
            
            chatController.navigationItem.hidesBackButton = true
            chatController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
            
            strongSelf.chatController = chatController
            strongSelf.addChild(chatController)
            strongSelf.view.addSubview(chatController.view)
            chatController.view.frame = strongSelf.view.bounds
            chatController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            chatController.didMove(toParent: strongSelf)
            
            // Give chat controller access to our navigation controller
            if let navigationController = strongSelf.navigationController as? NavigationController {
                chatController.navigation_setNavigationController(navigationController)
            }
            
            // Provide the initial layout to the chat controller
            if let layout = strongSelf.currentlyAppliedLayout {
                chatController.containerLayoutUpdated(layout, transition: .immediate)
                chatController.view.frame = CGRect(origin: .zero, size: layout.size)
            }
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let chatController = self.chatController {
            // Keep navigation controller reference up to date
            if let navigationController = self.navigationController as? NavigationController {
                chatController.navigation_setNavigationController(navigationController)
            }
            
            chatController.containerLayoutUpdated(layout, transition: transition)
            chatController.view.frame = CGRect(origin: .zero, size: layout.size)
        }
    }
}
