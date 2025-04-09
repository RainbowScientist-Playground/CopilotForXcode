import SwiftUI

public class ErrorMessageView: NSView {
    public init(errorMessage: String) {
        // Create a custom view for the menu item
        let maxWidth: CGFloat = 240
        let padding = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        
        // Initialize with temporary frame, will be adjusted
        super.init(frame: NSRect(x: 0, y: 0, width: maxWidth, height: 0))
        
        let textField = NSTextField(frame: .zero)
        textField.stringValue = errorMessage
        textField.isEditable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.lineBreakMode = .byWordWrapping
        textField.usesSingleLineMode = false
        textField.cell?.wraps = true
        textField.cell?.isScrollable = false
        textField.textColor = .secondaryLabelColor
        
        // Calculate the required height
        let fittingSize = textField.sizeThatFits(
            NSSize(width: maxWidth - padding.left - padding.right,
                  height: CGFloat.greatestFiniteMagnitude)
        )
        
        // Set the final frames
        self.frame = NSRect(
            x: 0, y: 0,
            width: maxWidth,
            height: fittingSize.height + padding.top + padding.bottom
        )
        
        textField.frame = NSRect(
            x: padding.left,
            y: padding.bottom,
            width: maxWidth - padding.left - padding.right,
            height: fittingSize.height
        )
        
        addSubview(textField)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
