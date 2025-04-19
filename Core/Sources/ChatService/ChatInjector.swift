import SuggestionBasic
import AppKit
import XcodeInspector
import AXHelper
import ApplicationServices
import AppActivator


public struct ChatInjector {
    public init() {}
    
    public func insertCodeBlock(codeBlock: String) {
        do {
            guard let editorContent = XcodeInspector.shared.focusedEditor?.getContent(),
                  let focusElement = XcodeInspector.shared.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            
            var cursorPosition = editorContent.cursorPosition
            guard cursorPosition.line >= 0, cursorPosition.character >= 0 else { return }
            
            var lines = editorContent.content.splitByNewLine(
                omittingEmptySubsequences: false
            ).map { String($0) }
            // Ensure the line number is within the bounds of the file
            guard cursorPosition.line <= lines.count else { return }
            
            var modifications: [Modification] = []
            
            // remove selection
            // make sure there is selection exist and valid
            if let selection = editorContent.selections.first,
                selection.isValid,
                selection.start.line < lines.endIndex {
                let selectionEndLine = min(selection.end.line, lines.count - 1)
                let deletedSelection = CursorRange(
                    start: selection.start,
                    end: .init(line: selectionEndLine, character: selection.end.character)
                )
                modifications.append(.deletedSelection(deletedSelection))
                lines = lines.applying([.deletedSelection(deletedSelection)])
                
                // update cursorPosition to the start of selection
                cursorPosition = selection.start
            }
            
            let targetLine = lines[cursorPosition.line]
            
            // Determine the indention level of the target line
            let leadingWhitespace = cursorPosition.character > 0 ? targetLine.prefix { $0.isWhitespace } : ""
            let indentation = String(leadingWhitespace)
            
            // Insert codeblock at the specified position
            let index = targetLine.index(targetLine.startIndex, offsetBy: min(cursorPosition.character, targetLine.count))
            let before = targetLine[..<index]
            let after = targetLine[index...]

            let codeBlockLines = codeBlock.splitByNewLine(
                omittingEmptySubsequences: false
            ).enumerated().map { (index, element) -> String in
                return index == 0 ? String(element) : indentation + String(element)
            }
            
            var toBeInsertedLines = [String]()
            toBeInsertedLines.append(String(before) + codeBlockLines.first!)
            toBeInsertedLines.append(contentsOf: codeBlockLines.dropFirst().dropLast())
            toBeInsertedLines.append(codeBlockLines.last! + String(after))
            
            lines.replaceSubrange((cursorPosition.line)...(cursorPosition.line), with: toBeInsertedLines)
            
            // Join the lines
            let newContent = String(lines.joined(separator: "\n"))
            
            // Inject updated content
            let newCursorPosition = CursorPosition(
                line: cursorPosition.line + codeBlockLines.count - 1,
                character: codeBlockLines.last?.count ?? 0
            )
            modifications.append(.inserted(cursorPosition.line, toBeInsertedLines))
            try AXHelper().injectUpdatedCodeWithAccessibilityAPI(
                .init(
                    content: newContent,
                    newSelection: .cursor(newCursorPosition),
                    modifications: modifications
                ),
                focusElement: focusElement,
                onSuccess: {
                    NSWorkspace.activatePreviousActiveXcode()
                }
                
            )
            
        } catch {
            print("Failed to insert code block: \(error)")
        }
    }
}
