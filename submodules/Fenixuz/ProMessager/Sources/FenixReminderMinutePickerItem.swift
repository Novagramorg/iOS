import Foundation
import UIKit
import AsyncDisplayKit
import Display

// Feature: "Reminder time" picker — lets the user pick ANY integer 1...60 minutes
// (instead of the fixed 1/5/10/30/60 preset list) using a UIPickerView embedded
// inside an ActionSheet item. Template: Display's ActionSheetCheckboxItem/Node.
public final class FenixReminderMinutePickerItem: ActionSheetItem {
    public let initialMinutes: Int
    public let titleForRow: (Int) -> String
    public let updated: (Int) -> Void

    public init(initialMinutes: Int, titleForRow: @escaping (Int) -> String, updated: @escaping (Int) -> Void) {
        self.initialMinutes = initialMinutes
        self.titleForRow = titleForRow
        self.updated = updated
    }

    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = FenixReminderMinutePickerItemNode(theme: theme)
        node.setItem(self)
        return node
    }

    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? FenixReminderMinutePickerItemNode else {
            assertionFailure()
            return
        }
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

private let fenixReminderPickerHeight: CGFloat = 180.0

public final class FenixReminderMinutePickerItemNode: ActionSheetItemNode, UIPickerViewDelegate, UIPickerViewDataSource {
    private let theme: ActionSheetControllerTheme
    private let font: UIFont

    private var item: FenixReminderMinutePickerItem?
    private let pickerView: UIPickerView

    override public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.font = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))

        self.pickerView = UIPickerView()

        super.init(theme: theme)

        self.pickerView.delegate = self
        self.pickerView.dataSource = self
        self.view.addSubview(self.pickerView)
    }

    func setItem(_ item: FenixReminderMinutePickerItem) {
        let isFirstItem = self.item == nil
        self.item = item

        self.pickerView.reloadAllComponents()

        if isFirstItem {
            let row = max(0, min(59, item.initialMinutes - 1))
            self.pickerView.selectRow(row, inComponent: 0, animated: false)
        }
    }

    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: fenixReminderPickerHeight)

        self.pickerView.frame = CGRect(origin: CGPoint(), size: size)

        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }

    // MARK: - UIPickerViewDataSource

    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 60
    }

    // MARK: - UIPickerViewDelegate

    public func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
        return 40.0
    }

    public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        guard let item = self.item else {
            return nil
        }
        let title = item.titleForRow(row + 1)
        return NSAttributedString(string: title, font: self.font, textColor: self.theme.primaryTextColor)
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        self.item?.updated(row + 1)
    }
}
