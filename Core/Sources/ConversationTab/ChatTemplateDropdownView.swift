import ConversationServiceProvider
import AppKit
import SwiftUI
import ComposableArchitecture

public struct ChatTemplateDropdownView: View {
    @Binding var templates: [ChatTemplate]
    let onSelect: (ChatTemplate) -> Void
    @State private var selectedIndex = 0
    @State private var frameHeight: CGFloat = 0
    @State private var localMonitor: Any? = nil

    public var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                    HStack {
                        Text("/" + template.id)
                            .hoverPrimaryForeground(isHovered: selectedIndex == index)
                        Spacer()
                        Text(template.shortDescription)
                            .hoverSecondaryForeground(isHovered: selectedIndex == index)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(template)
                    }
                    .hoverBackground(isHovered: selectedIndex == index)
                    .onHover { isHovered in
                        if isHovered {
                            selectedIndex = index
                        }
                    }
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { frameHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { newHeight in
                            frameHeight = newHeight
                        }
                }
            )
            .background(.ultraThickMaterial)
            .cornerRadius(6)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .frame(maxWidth: .infinity)
            .offset(y: -1 * frameHeight)
            .onChange(of: templates) { _ in
                selectedIndex = 0
            }
            .onAppear {
                selectedIndex = 0
                localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    switch event.keyCode {
                    case 126: // Up arrow
                        moveSelection(up: true)
                        return nil
                    case 125: // Down arrow
                        moveSelection(up: false)
                        return nil
                    case 36: // Return key
                        handleEnter()
                        return nil
                    case 48: // Tab key
                        handleTab()
                        return nil // not forwarding the Tab Event which will replace the typed message to "\t"
                    default:
                        break
                    }
                    return event
                }
            }
            .onDisappear {
                if let monitor = localMonitor {
                    NSEvent.removeMonitor(monitor)
                    localMonitor = nil
                }
            }
        }
    }

    private func moveSelection(up: Bool) {
        guard !templates.isEmpty else { return }
        let lowerBound = 0
        let upperBound = templates.count - 1
        let newIndex = selectedIndex + (up ? -1 : 1)
        selectedIndex = newIndex < lowerBound ? upperBound : (newIndex > upperBound ? lowerBound : newIndex)
    }
    
    private func handleEnter() {
        handleTemplateSelection()
    }
    
    private func handleTab() {
        handleTemplateSelection()
    }
    
    private func handleTemplateSelection() {
        if templates.count > 0 && selectedIndex < templates.count {
            onSelect(templates[selectedIndex])
        }
    }
}
