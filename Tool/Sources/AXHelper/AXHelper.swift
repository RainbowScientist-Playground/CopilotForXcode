import XPCShared
import XcodeInspector
import AppKit

public struct AXHelper {
    public init() {}
    
    /// When Xcode commands are not available, we can fallback to directly
    /// set the value of the editor with Accessibility API.
    public func injectUpdatedCodeWithAccessibilityAPI(
        _ result: UpdatedContent,
        focusElement: AXUIElement,
        onSuccess: (() -> Void)? = nil,
        onError: (() -> Void)? = nil
    ) throws {
        let oldPosition = focusElement.selectedTextRange
        let oldScrollPosition = focusElement.parent?.verticalScrollBar?.doubleValue

        let error = AXUIElementSetAttributeValue(
            focusElement,
            kAXValueAttribute as CFString,
            result.content as CFTypeRef
        )

        if error != AXError.success {
            if let onError = onError {
                onError()
            }
        }

        // recover selection range
        if let selection = result.newSelection {
            var range = SourceEditor.convertCursorRangeToRange(selection, in: result.content)
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        } else if let oldPosition {
            var range = CFRange(
                location: oldPosition.lowerBound,
                length: 0
            )
            if let value = AXValueCreate(.cfRange, &range) {
                AXUIElementSetAttributeValue(
                    focusElement,
                    kAXSelectedTextRangeAttribute as CFString,
                    value
                )
            }
        }

        // recover scroll position
        if let oldScrollPosition,
           let scrollBar = focusElement.parent?.verticalScrollBar
        {
            AXUIElementSetAttributeValue(
                scrollBar,
                kAXValueAttribute as CFString,
                oldScrollPosition as CFTypeRef
            )
        }
        
        if let onSuccess = onSuccess {
            onSuccess()
        }
    }
}
