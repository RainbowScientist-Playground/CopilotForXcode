import ComposableArchitecture
import ConversationServiceProvider
import SharedUIComponents
import SwiftUI

public struct FilePicker: View {
    @Binding var allFiles: [FileReference]
    var onSubmit: (_ file: FileReference) -> Void
    var onExit: () -> Void
    @FocusState private var isSearchBarFocused: Bool
    @State private var searchText = ""
    @State private var selectedId: Int = 0
    @State private var localMonitor: Any? = nil

    private var filteredFiles: [FileReference] {
        if searchText.isEmpty {
            return allFiles
        }

        return allFiles.filter { doc in
            (doc.fileName ?? doc.url.lastPathComponent) .localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(searchText.isEmpty ? Color(nsColor: .placeholderTextColor) : Color(nsColor: .textColor))
                        .focused($isSearchBarFocused)
                        .onChange(of: searchText) { newValue in
                            selectedId = 0
                        }
                        .onAppear() {
                            isSearchBarFocused = true
                        }

                    Button(action: {
                        withAnimation {
                            onExit()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Close")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
                .cornerRadius(6)
                .padding(.horizontal, 4)
                .padding(.top, 4)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(filteredFiles.enumerated()), id: \.element) { index, doc in
                                FileRowView(doc: doc, id: index, selectedId: $selectedId)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        onSubmit(doc)
                                        selectedId = index
                                        isSearchBarFocused = true
                                    }
                                    .id(index)
                            }
                            
                            if filteredFiles.isEmpty {
                                Text("No results found")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.vertical, 4)
                            }
                        }
                        .id(filteredFiles.hashValue)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .onAppear {
                        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if !isSearchBarFocused { // if file search bar is not focused, ignore the event
                                return event
                            }

                            switch event.keyCode {
                            case 126: // Up arrow
                                moveSelection(up: true, proxy: proxy)
                                return nil
                            case 125: // Down arrow
                                moveSelection(up: false, proxy: proxy)
                                return nil
                            case 36: // Return key
                                handleEnter()
                                return nil
                            case 53: // Esc key
                                withAnimation {
                                    onExit()
                                }
                                return nil
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
            .fixedSize(horizontal: false, vertical: true)
            .cornerRadius(6)
            .shadow(radius: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.horizontal, 12)
        }
    }

    private func moveSelection(up: Bool, proxy: ScrollViewProxy) {
        let files = filteredFiles
        guard !files.isEmpty else { return }
        let nextId = selectedId + (up ? -1 : 1)
        selectedId = max(0, min(nextId, files.count - 1))
        proxy.scrollTo(selectedId, anchor: .bottom)
    }

    private func handleEnter() {
        let files = filteredFiles
        guard !files.isEmpty && selectedId < files.count else { return }
        onSubmit(files[selectedId])
    }
}

struct FileRowView: View {
    @State private var isHovered = false
    let doc: FileReference
    let id: Int
    @Binding var selectedId: Int

    var body: some View {
        WithPerceptionTracking {
            HStack {
                drawFileIcon(doc.url)
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
                
                VStack(alignment: .leading) {
                    Text(doc.fileName ?? doc.url.lastPathComponent)
                        .font(.body)
                        .hoverPrimaryForeground(isHovered: selectedId == id)
                    Text(doc.relativePath ?? doc.url.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .hoverRadiusBackground(isHovered: isHovered || selectedId == id,
                                   hoverColor: (selectedId == id ? nil : Color.gray.opacity(0.1)),
                                   cornerRadius: 6)
            .onHover(perform: { hovering in
                isHovered = hovering
            })
        }
    }
}
