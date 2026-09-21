import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @Bindable var note: Note
    @ObservedObject var controller: DocumentController
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newTag = ""
    @State private var showIconPicker = false
    @State private var showHeaderOptions = false
    @State private var headerHovering = false
    @State private var coverHovering = false
    @FocusState private var tagFieldFocused: Bool

    private static let icons = [
        "📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪",
        "🎯", "🏗️", "📚", "🧠", "💬", "🗂️", "⭐️", "🔥",
    ]

    var body: some View {
        VStack(spacing: 0) {
            if note.hasCover { cover }
            header
            Divider()
            FormatToolbar(controller: controller)
            Divider()
            HStack(spacing: 0) {
                PagedEditor(controller: controller)
                if showInspector {
                    Divider()
                    InspectorPanel(controller: controller, tab: $inspectorTab)
                        .transition(.move(edge: .trailing))
                }
            }
            .animation(.easeInOut(duration: 0.18), value: showInspector)
            Divider()
            statusBar
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Bảng điều khiển", systemImage: "sidebar.right")
                }
                .help("Ẩn/hiện bảng bên phải (⌃⌘O)")
            }
        }
    }

    // MARK: - Cover

    private var cover: some View {
        ZStack(alignment: .bottomTrailing) {
            CoverView(note: note)
                .frame(height: note.coverHeight)
                .frame(maxWidth: .infinity)
                .clipped()

            if coverHovering {
                HStack(spacing: 6) {
                    coverMenu(label: "Đổi ảnh bìa")
                    Button("Bỏ") { removeCover() }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(10)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: coverHovering)
        .onHover { coverHovering = $0 }
    }

    private func coverMenu(label: String) -> some View {
        Menu(label) {
            Button("Chọn ảnh…") { pickCoverFile() }
            Button("Dán ảnh từ clipboard") { pasteCover() }
                .disabled(NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil) == false)
            Section("Màu nền") {
                ForEach(CoverStyle.allCases) { style in
                    Button(style.label) {
                        note.coverData = nil
                        note.coverStyle = style.rawValue
                        note.touch()
                    }
                }
            }
            Section("Chiều cao") {
                Button("Thấp") { note.coverHeight = 120 }
                Button("Vừa") { note.coverHeight = 180 }
                Button("Cao") { note.coverHeight = 260 }
            }
            if note.hasCover {
                Divider()
                Button("Bỏ ảnh bìa", role: .destructive) { removeCover() }
            }
        }
    }

    private func pickCoverFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Đặt làm ảnh bìa"
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        setCover(image)
    }

    private func pasteCover() {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else { return }
        setCover(image)
    }

    private func setCover(_ image: NSImage) {
        note.coverData = image.coverData()
        note.coverStyle = ""
        note.touch()
    }

    private func removeCover() {
        note.coverData = nil
        note.coverStyle = ""
        note.touch()
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: note.headerAlignment == .center ? .center : .leading, spacing: 6) {
            if headerHovering && !note.hasCover {
                HStack(spacing: 8) {
                    coverMenu(label: "Thêm ảnh bìa")
                    Button("Tùy chỉnh đầu trang") { showHeaderOptions.toggle() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: note.headerAlignment == .center ? .center : .leading)
            }

            HStack(alignment: .center, spacing: 12) {
                if note.headerAlignment == .center { Spacer(minLength: 0) }
                if note.showIcon { iconButton }
                TextField("Trang không tên", text: $note.title)
                    .textFieldStyle(.plain)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(note.headerAlignment == .center ? .center : .leading)
                    .fixedSize(horizontal: note.headerAlignment == .center, vertical: false)
                    .onChange(of: note.title) { _, _ in note.touch() }
                if note.headerAlignment == .center { Spacer(minLength: 0) }
                if note.headerAlignment == .leading { tagsEditor }
            }

            if !note.subtitle.isEmpty || showHeaderOptions {
                TextField("Mô tả ngắn cho trang này", text: $note.subtitle)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(note.headerAlignment == .center ? .center : .leading)
                    .onChange(of: note.subtitle) { _, _ in note.touch() }
            }

            if note.headerAlignment == .center { tagsEditor }
        }
        .padding(.horizontal, 16)
        .padding(.top, note.hasCover ? 10 : 8)
        .padding(.bottom, 10)
        .onHover { headerHovering = $0 }
        .popover(isPresented: $showHeaderOptions, arrowEdge: .bottom) { headerOptions }
        .contextMenu {
            Button("Tùy chỉnh đầu trang…") { showHeaderOptions = true }
            coverMenu(label: note.hasCover ? "Ảnh bìa" : "Thêm ảnh bìa")
        }
    }

    private var iconButton: some View {
        Button {
            showIconPicker.toggle()
        } label: {
            Text(note.icon)
                .font(.system(size: 26))
                .frame(width: 40, height: 40)
                .background(Color.primary.opacity(0.05), in: .rect(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .help("Đổi biểu tượng trang")
        .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(34)), count: 5), spacing: 4) {
                ForEach(Self.icons, id: \.self) { icon in
                    Button {
                        note.icon = icon
                        note.touch()
                        showIconPicker = false
                    } label: {
                        Text(icon)
                            .font(.system(size: 20))
                            .frame(width: 32, height: 32)
                            .background(note.icon == icon ? Color.accentColor.opacity(0.18) : .clear, in: .rect(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
    }

    private var headerOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Đầu trang")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Canh tiêu đề", selection: Binding(get: { note.headerAlignment }, set: { note.headerAlignment = $0 })) {
                ForEach(HeaderAlignment.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Hiện biểu tượng", isOn: $note.showIcon)
            Toggle("Ảnh bìa", isOn: Binding(
                get: { note.hasCover },
                set: { on in
                    if on { note.coverStyle = CoverStyle.ocean.rawValue } else { removeCover() }
                }
            ))
            if note.hasCover {
                Picker("Chiều cao bìa", selection: $note.coverHeight) {
                    Text("Thấp").tag(120.0)
                    Text("Vừa").tag(180.0)
                    Text("Cao").tag(260.0)
                }
                .pickerStyle(.segmented)
            }
            Text("Mô tả ngắn hiện ngay dưới tiêu đề; để trống thì ẩn.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 260)
    }

    private var tagsEditor: some View {
        HStack(spacing: 6) {
            ForEach(note.tags, id: \.self) { tag in
                TagChip(name: tag, color: tags.color(for: tag)) {
                    note.tags.removeAll { $0 == tag }
                    note.touch()
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "tag")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                TextField(note.tags.isEmpty ? "Thêm thẻ" : "Thêm", text: $newTag)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(width: note.tags.isEmpty ? 70 : 46)
                    .focused($tagFieldFocused)
                    .onSubmit(commitTag)
                    .onChange(of: newTag) { _, value in
                        if value.hasSuffix(",") { commitTag() }
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(tagFieldFocused ? 0.08 : 0.04), in: .capsule)
            .popover(isPresented: Binding(get: { tagFieldFocused && !suggestions.isEmpty }, set: { _ in }), arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(suggestions, id: \.key) { tag in
                        Button {
                            addTag(tag.name)
                        } label: {
                            HStack(spacing: 6) {
                                Circle().fill(tag.color.color).frame(width: 8, height: 8)
                                Text(tag.name)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .frame(width: 180)
            }
        }
    }

    /// Existing tags matching what is being typed, not already on the page.
    private var suggestions: [Tag] {
        let needle = Tag.key(for: newTag)
        let present = Set(note.tags.map { Tag.key(for: $0) })
        return tags
            .filter { !present.contains($0.key) && (needle.isEmpty || $0.key.contains(needle)) }
            .prefix(6)
            .map { $0 }
    }

    private func commitTag() {
        let parsed = Note.parseTags(newTag)
        newTag = ""
        for tag in parsed { addTag(tag) }
    }

    private func addTag(_ raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let key = Tag.key(for: name)
        guard !note.tags.contains(where: { Tag.key(for: $0) == key }) else { return }
        // Reuse the catalogue spelling when the tag already exists.
        let canonical = tags.first { $0.key == key }?.name ?? name
        TagStore.ensure(canonical, in: context)
        note.tags.append(canonical)
        note.touch()
        newTag = ""
    }

    // MARK: - Status bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            saveIndicator
            Divider().frame(height: 12)
            Text("\(controller.pageCount) trang · \(controller.wordCount) từ · \(controller.characterCount) ký tự")
                .monospacedDigit()
            Divider().frame(height: 12)
            Text("\(controller.config.paper.label) \(controller.config.orientation.label.lowercased()) · lề \(Unit.centimeters(controller.config.margins.left)) cm")

            Spacer()

            Text("Gõ / để chèn khối")
                .foregroundStyle(.tertiary)

            Divider().frame(height: 12)
            statusToggle("Thước", icon: "ruler", keyPath: \.showRuler)
            statusToggle("Lưới", icon: "grid", keyPath: \.showGrid)

            Divider().frame(height: 12)
            zoomControls
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var saveIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: controller.hasUnsavedChanges ? "circle.fill" : "checkmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(controller.hasUnsavedChanges ? Color.orange : Color.green)
            Text(controller.hasUnsavedChanges ? "Đang lưu…" : "Đã lưu \(note.updatedAt.formatted(date: .omitted, time: .shortened))")
        }
        .animation(.easeInOut(duration: 0.2), value: controller.hasUnsavedChanges)
    }

    private func statusToggle(_ label: String, icon: String, keyPath: WritableKeyPath<CanvasOptions, Bool>) -> some View {
        let isOn = controller.canvasOptions[keyPath: keyPath]
        return Button {
            controller.canvasOptions[keyPath: keyPath].toggle()
        } label: {
            Label(label, systemImage: icon)
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
        }
        .buttonStyle(.borderless)
        .help("Ẩn/hiện \(label.lowercased())")
    }

    private var zoomControls: some View {
        HStack(spacing: 2) {
            Button {
                controller.setZoom((controller.effectiveZoom - 0.1).rounded(toPlaces: 1))
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Thu nhỏ")

            Menu {
                Button("Vừa chiều rộng") { controller.zoomToFitWidth() }
                    .disabled(controller.canvasOptions.fitWidth)
                Divider()
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { value in
                    Button("\(Int(value * 100))%") { controller.setZoom(CGFloat(value)) }
                }
            } label: {
                Text(controller.canvasOptions.fitWidth
                    ? "Vừa · \(Int((controller.effectiveZoom * 100).rounded()))%"
                    : "\(Int((controller.effectiveZoom * 100).rounded()))%")
                    .monospacedDigit()
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Thu phóng — Vừa chiều rộng tự co giãn theo cửa sổ (⌘9)")

            Button {
                controller.setZoom((controller.effectiveZoom + 0.1).rounded(toPlaces: 1))
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Phóng to")
        }
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
