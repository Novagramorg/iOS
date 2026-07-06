import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import AppBundle
import ContextUI
import Markdown
import Postbox

// MARK: - EditedMessageHistoryController
public final class EditedMessageHistoryController: ViewController {
    private let context: AccountContext
    private let message: Message
    private var presentationData: PresentationData
    private var presentationDataDisposable: MetaDisposable?
    
    private let listNode: EditedMessageHistoryListNode
    
    public init(context: AccountContext, message: Message) {
        self.context = context
        self.message = message
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.listNode = EditedMessageHistoryListNode(context: context, message: message, presentationData: self.presentationData)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = self.presentationData.strings.Conversation_Edit
        
        self.presentationDataDisposable = MetaDisposable()
        self.presentationDataDisposable?.set((context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        }))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData), transition: .immediate)
        self.title = self.presentationData.strings.Conversation_Edit
        self.listNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = self.listNode
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        self.listNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

// MARK: - EditedMessageHistoryListNode
private final class EditedMessageHistoryListNode: ASDisplayNode {
    private let context: AccountContext
    private let message: Message
    private var presentationData: PresentationData
    
    private let scrollNode: ASScrollNode
    private var historyEntries: [EditedMessageHistoryEntry] = []
    private var entryNodes: [EditedMessageHistoryEntryNode] = []
    
    init(context: AccountContext, message: Message, presentationData: PresentationData) {
        self.context = context
        self.message = message
        self.presentationData = presentationData
        
        self.scrollNode = ASScrollNode()
        self.scrollNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        super.init()
        
        self.addSubnode(self.scrollNode)
        
        if let historyAttribute = message.attributes.first(where: { $0 is EditedMessageHistoryAttribute }) as? EditedMessageHistoryAttribute {
            // Sort history by timestamp descending (newest edits first)
            self.historyEntries = historyAttribute.history.sorted(by: { $0.timestamp > $1.timestamp })
        }
        
        for entry in self.historyEntries {
            let node = EditedMessageHistoryEntryNode(entry: entry, presentationData: presentationData)
            self.entryNodes.append(node)
            self.scrollNode.addSubnode(node)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.scrollNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        // Can re-initialize nodes here, but skipping for simplicity
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.view.contentInset = insets
        self.scrollNode.view.scrollIndicatorInsets = insets
        
        var currentY: CGFloat = 0.0
        for node in self.entryNodes {
            let size = node.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
            node.frame = CGRect(origin: CGPoint(x: 0.0, y: currentY), size: size)
            currentY += size.height
        }
        
        self.scrollNode.view.contentSize = CGSize(width: layout.size.width, height: currentY)
    }
}

// MARK: - EditedMessageHistoryEntryNode
private final class EditedMessageHistoryEntryNode: ASDisplayNode {
    private let entry: EditedMessageHistoryEntry
    private let presentationData: PresentationData
    
    private let backgroundNode: ASDisplayNode
    private let dateTextNode: ASTextNode
    private let textNode: ASTextNode
    private let separatorNode: ASDisplayNode
    
    init(entry: EditedMessageHistoryEntry, presentationData: PresentationData) {
        self.entry = entry
        self.presentationData = presentationData
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        self.dateTextNode = ASTextNode()
        self.dateTextNode.isUserInteractionEnabled = false
        
        let dateString = stringForTimestamp(timestamp: entry.timestamp, strings: presentationData.strings)
        self.dateTextNode.attributedText = NSAttributedString(string: dateString, font: Font.regular(14.0), textColor: presentationData.theme.list.itemSecondaryTextColor)
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.attributedText = NSAttributedString(string: entry.text, font: Font.regular(17.0), textColor: presentationData.theme.list.itemPrimaryTextColor)
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.dateTextNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.separatorNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let insets = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 12.0, right: 16.0)
        let textWidth = constrainedSize.width - insets.left - insets.right
        
        let dateSize = self.dateTextNode.measure(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.measure(CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let totalHeight = insets.top + dateSize.height + 6.0 + textSize.height + insets.bottom
        return CGSize(width: constrainedSize.width, height: totalHeight)
    }
    
    override func layout() {
        super.layout()
        
        let insets = UIEdgeInsets(top: 12.0, left: 16.0, bottom: 12.0, right: 16.0)
        let bounds = self.bounds
        self.backgroundNode.frame = bounds
        
        let dateSize = self.dateTextNode.calculatedSize
        self.dateTextNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: dateSize)
        
        let textSize = self.textNode.calculatedSize
        self.textNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top + dateSize.height + 6.0), size: textSize)
        
        let separatorHeight = UIScreenPixel
        self.separatorNode.frame = CGRect(x: 16.0, y: bounds.size.height - separatorHeight, width: bounds.size.width - 16.0, height: separatorHeight)
    }
}

private func stringForTimestamp(timestamp: Int32, strings: PresentationStrings) -> String {
    let date = Date(timeIntervalSince1970: Double(timestamp))
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}
