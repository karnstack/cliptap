import AppKit
import SwiftUI
import ServiceManagement

/// Shared state between the panel (keyboard handling) and the SwiftUI view.
@MainActor
final class PanelState: ObservableObject {
    @Published var query = ""
    @Published var selection: UUID?
    @Published var copiedID: UUID?
    @Published var focusToken = 0
    @Published var confirmClear = false
    /// Mouse position at the last hover-select. Rows scrolling under a still mouse must not steal selection.
    var lastMouse = NSPoint(x: -1, y: -1)
}

// MARK: - UI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct Keycap: View {
    let key: String
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 17)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.07)))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.08)))
            Text(label)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }
}

struct IconButton: View {
    let symbol: String
    let help: String
    var role: ButtonRole? = nil
    let action: () -> Void
    @State private var hover = false
    var body: some View {
        Button(role: role, action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .foregroundStyle(hover && role == .destructive ? Color.red : (hover ? .primary : .secondary))
                .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.15), value: hover)
        .help(help)
    }
}

struct HistoryView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var state: PanelState
    var onPick: (ClipItem) -> Void
    var onDelete: (ClipItem) -> Void
    var onCheckForUpdates: () -> Void
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @FocusState private var searchFocused: Bool

    var filtered: [ClipItem] { HistoryView.filter(store.items, state.query) }
    var selected: ClipItem? { store.items.first { $0.id == state.selection } }

    static func filter(_ items: [ClipItem], _ query: String) -> [ClipItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let base = q.isEmpty ? items : items.filter { $0.text.localizedCaseInsensitiveContains(q) }
        return base.filter { $0.pinned } + base.filter { !$0.pinned }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                HStack(spacing: 0) {
                    list.frame(width: 320)
                    Divider()
                    PreviewPane(item: selected, store: store,
                                copied: selected.map { state.copiedID == $0.id } ?? false,
                                onCopy: { if let s = selected { onPick(s) } },
                                onPin: { if let s = selected { store.togglePin(s) } },
                                onDelete: { if let s = selected { onDelete(s) } })
                }
            }
            Divider()
            footer
        }
        .frame(width: 780, height: 500)
        .background(VisualEffect())
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .onAppear { searchFocused = true }
        .onChange(of: state.focusToken) { _, _ in searchFocused = true }
        .alert("Clear clipboard history?", isPresented: $state.confirmClear) {
            Button("Clear history", role: .destructive) { store.clearUnpinned() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all items except pinned ones. You can't undo this.")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $state.query)
                .textFieldStyle(.plain)
                .font(.system(size: 17))
                .focused($searchFocused)
            if !state.query.isEmpty {
                Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tertiary)
                    .help("Clear search")
            }
            Text("\(filtered.count) \(filtered.count == 1 ? "item" : "items")")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var list: some View {
        let pinned = filtered.filter { $0.pinned }
        let recent = filtered.filter { !$0.pinned }
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if !pinned.isEmpty {
                        SectionHeader(title: "Pinned")
                        rows(pinned, offset: 0)
                    }
                    if !recent.isEmpty {
                        SectionHeader(title: pinned.isEmpty ? "Recent" : "Recent")
                        rows(recent, offset: pinned.count)
                    }
                }
                .padding(6)
            }
            .onChange(of: state.selection) { _, id in
                guard let id else { return }
                proxy.scrollTo(id)
            }
        }
    }

    @ViewBuilder
    private func rows(_ items: [ClipItem], offset: Int) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
            Row(item: item,
                thumbnail: store.thumbnail(for: item),
                shortcut: offset + i < 9 ? "⌘\(offset + i + 1)" : nil,
                selected: state.selection == item.id,
                copied: state.copiedID == item.id)
            .id(item.id)
            .onHover { inside in
                let mouse = NSEvent.mouseLocation
                guard inside, mouse != state.lastMouse else { return }
                state.lastMouse = mouse
                state.selection = item.id
            }
            .onTapGesture { onPick(item) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: state.query.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 4)
            Text(state.query.isEmpty ? "Nothing copied yet" : "No results for “\(state.query)”")
                .font(.system(size: 14, weight: .semibold))
            Text(state.query.isEmpty
                 ? "Copy text or an image and it shows up here.\nPress ⌘ twice (or ⌃⌘V) to open this from anywhere."
                 : "Try a shorter or different word.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Keycap(key: "↑↓", label: "Select")
            Keycap(key: "↩", label: "Copy")
            Keycap(key: "⌘1–9", label: "Quick copy")
            Keycap(key: "⌘P", label: "Pin")
            Keycap(key: "⌘⌫", label: "Delete")
            Keycap(key: "esc", label: "Close")
            Spacer()
            Menu {
                Toggle("Open at login", isOn: $launchAtLogin)
                if !DoubleTapCommand.hasPermission {
                    Button("Turn on double ⌘ shortcut…") {
                        DoubleTapCommand.askPermission()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
                Divider()
                Button("Clear history…") { state.confirmClear = true }
                    .disabled(store.items.allSatisfy { $0.pinned })
                Button("Check for updates…", action: onCheckForUpdates)
                Divider()
                Text("Cliptap \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                Button("Quit Cliptap") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Settings")
            .onChange(of: launchAtLogin) { _, on in
                do {
                    if on { try SMAppService.mainApp.register() }
                    else { try SMAppService.mainApp.unregister() }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

struct Row: View {
    let item: ClipItem
    let thumbnail: NSImage?
    let shortcut: String?
    let selected: Bool
    let copied: Bool

    private var oneLine: String {
        item.text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: item.isImage ? "photo" : "text.alignleft")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 24, height: 24)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 5))

            Text(oneLine)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack(alignment: .trailing) {
                if copied {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                } else if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 28, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(selected ? Color.accentColor.opacity(0.2) : .clear))
        .contentShape(Rectangle())
    }
}

struct PreviewPane: View {
    let item: ClipItem?
    let store: ClipStore
    let copied: Bool
    let onCopy: () -> Void
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        if let item {
            VStack(spacing: 0) {
                content(item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                details(item)
            }
        } else {
            Text("Select an item to preview it")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func content(_ item: ClipItem) -> some View {
        if let image = store.thumbnail(for: item) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.08)))
                .padding(20)
        } else {
            ScrollView {
                Text(item.text)
                    .font(.system(size: 13))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private func details(_ item: ClipItem) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                if item.isImage {
                    detail("Type", "Image")
                    detail("Size", item.text.replacingOccurrences(of: "Image ", with: ""))
                } else {
                    detail("Type", "Text")
                    detail("Characters", item.text.count.formatted())
                    detail("Lines", (item.text.split(whereSeparator: \.isNewline).count).formatted())
                }
                detail("Copied", item.date.formatted(.relative(presentation: .named)))
            }
            HStack(spacing: 4) {
                Button(action: onCopy) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(minWidth: 70)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                Spacer()
                IconButton(symbol: item.pinned ? "pin.slash" : "pin",
                           help: item.pinned ? "Unpin (⌘P)" : "Pin (⌘P)", action: onPin)
                IconButton(symbol: "trash", help: "Delete (⌘⌫)", role: .destructive, action: onDelete)
            }
        }
        .padding(14)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}
