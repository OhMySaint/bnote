import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Where the sheet sits inside the scrolling canvas; the header column follows it.
final class HeaderLayout: ObservableObject {
    @Published var leading: CGFloat = 36
    @Published var width: CGFloat = 595
}

/// Notion-style page top, hosted inside the scrolling canvas above the first
/// sheet: edge-to-edge cover, icon straddling its bottom edge, big title,
/// optional subtitle, tags.
struct PageHeaderView: View {
    @Bindable var note: Note
    @ObservedObject var layout: HeaderLayout

    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var tags: [Tag]

    @State private var newTag = ""
    @State private var showIconPicker = false
    @State private var showHeaderOptions = false
    @State private var headerHovering = false
    @State private var coverHovering = false
    @State private var repositioning = false
    @State private var repositionOffset = 0.5
    @State private var repositionStart = 0.5
    @FocusState private var tagFieldFocused: Bool

    private static let icons = [
        "📄", "📝", "📘", "🗒️", "📊", "🧩", "🚀", "💡", "🗓️", "✅", "🔖", "🧪",
        "🎯", "🏗️", "📚", "🧠", "💬", "🗂️", "⭐️", "🔥",
    ]

    static let titleFont = NSFont.systemFont(ofSize: 34, weight: .bold)

    /// Deterministic height so the canvas can place the first sheet below.
    static func height(for note: Note, width: CGFloat) -> CGFloat {
        var total: CGFloat = note.hasCover ? note.coverHeight : 16
        total += note.showIcon ? (note.hasCover ? 66 - 28 : 50 + 6) : 0
        total += 22 + 4 // ghost action row
        let bounding = (note.title.isEmpty ? "Trang" : note.title) as NSString
        let titleRect = bounding.boundingRect(
            with: NSSize(width: max(100, width - 8), height: 400),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleFont]
        )
        total += min(max(ceil(titleRect.height) + 8, 46), 140)
        if !note.subtitle.isEmpty { total += 24 }
        total += 30 // tags row
        total += 16
        return ceil(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if note.hasCover { cover }
            header
                .padding(.leading, layout.leading)
                .frame(width: layout.leading + layout.width, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Cover (Notion style: edge-to-edge banner, icon overlapping its bottom edge)

    private var cover: some View {
        ZStack(alignment: .bottomTrailing) {
            CoverView(note: note, offsetOverride: repositioning ? repositionOffset : nil)
                .frame(height: note.coverHeight)
                .frame(maxWidth: .infinity)
                .clipped()
                .contentShape(.rect)
                .gesture(repositionDrag)

            // Buttons live inside the banner, so showing them never moves anything.
            HStack(spacing: 6) {
                if repositioning {
                    Button("Lưu vị trí") { commitReposition() }
                    Button("Hủy") { repositioning = false }
                } else {
                    coverMenu(label: "Đổi ảnh bìa")
                    if note.coverData != nil {
                        Button("Chỉnh vị trí") { startReposition() }
                    }
                    Button("Bỏ") { removeCover() }
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(10)
            .opacity(coverHovering || repositioning ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: coverHovering)

            if repositioning {
                Text("Kéo ảnh để chỉnh vị trí")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.regularMaterial, in: .capsule)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 10)
            }
        }
        .onHover { coverHovering = $0 }
    }

    private var repositionDrag: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard repositioning, let data = note.coverData, let image = NSImage(data: data) else { return }
                // How much taller the fitted picture is than the banner decides drag sensitivity.
                let bannerWidth = max(1, NSApp.keyWindow?.contentView?.bounds.width ?? 900)
                let fittedHeight = image.size.height * bannerWidth / max(image.size.width, 1)
                let overflow = max(1, fittedHeight - note.coverHeight)
                repositionOffset = min(1, max(0, repositionStart - value.translation.height / overflow))
            }
            .onEnded { _ in
                guard repositioning else { return }
                repositionStart = repositionOffset
            }
    }

    private func startReposition() {
        repositionOffset = note.coverOffset
        repositionStart = note.coverOffset
        repositioning = true
    }

    private func commitReposition() {
        note.coverOffset = repositionOffset
        note.touch()
        repositioning = false
    }

    private func coverMenu(label: String) -> some View {
        Menu(label) {
            Button("Chọn ảnh…") { pickCoverFile() }
            Button("Dán ảnh từ clipboard") { pasteCover() }
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
                Button("Thấp") { note.coverHeight = 140 }
                Button("Vừa") { note.coverHeight = 200 }
                Button("Cao") { note.coverHeight = 280 }
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
        note.coverOffset = 0.5
        note.touch()
    }

    private func removeCover() {
        note.coverData = nil
        note.coverStyle = ""
        repositioning = false
        note.touch()
    }

    // MARK: - Header

    private var centered: Bool { note.headerAlignment == .center }

    private var header: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 4) {
            // Icon straddles the banner's bottom edge when there is a cover.
            HStack {
                if centered { Spacer(minLength: 0) }
                if note.showIcon {
                    iconButton
                        .padding(.top, note.hasCover ? -28 : 6)
                }
                if centered { Spacer(minLength: 0) }
            }

            // Ghost actions: always laid out, only visible on hover, so nothing shifts.
            HStack(spacing: 10) {
                if !note.showIcon {
                    ghostButton("face.smiling", "Thêm biểu tượng") { note.showIcon = true }
                }
                if !note.hasCover {
                    coverMenu(label: "Thêm ảnh bìa")
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                }
                ghostButton("slider.horizontal.3", "Tùy chỉnh") { showHeaderOptions.toggle() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(height: 22)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .opacity(headerHovering ? 1 : 0)
            .animation(.easeOut(duration: 0.12), value: headerHovering)

            TextField("Trang không tên", text: $note.title, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 34, weight: .bold))
                .lineLimit(1...3)
                .multilineTextAlignment(centered ? .center : .leading)
                .onChange(of: note.title) { _, _ in note.touch() }

            if !note.subtitle.isEmpty || showHeaderOptions {
                TextField("Mô tả ngắn cho trang này", text: $note.subtitle)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(centered ? .center : .leading)
                    .onChange(of: note.subtitle) { _, _ in note.touch() }
            }

            tagsEditor
                .padding(.top, 4)
        }
        .padding(.trailing, 8)
        .padding(.top, note.hasCover ? 0 : 4)
        .padding(.bottom, 12)
        .onHover { headerHovering = $0 }
        .popover(isPresented: $showHeaderOptions, arrowEdge: .bottom) { headerOptions }
        .contextMenu {
            Button("Tùy chỉnh đầu trang…") { showHeaderOptions = true }
            coverMenu(label: note.hasCover ? "Ảnh bìa" : "Thêm ảnh bìa")
        }
    }

    private func ghostButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(.borderless)
    }

    private var iconButton: some View {
        Button {
            showIconPicker.toggle()
        } label: {
            Text(note.icon)
                .font(.system(size: note.hasCover ? 46 : 34))
                .frame(width: note.hasCover ? 66 : 50, height: note.hasCover ? 66 : 50)
                .background(note.hasCover ? AnyShapeStyle(.background) : AnyShapeStyle(Color.primary.opacity(0.05)), in: .rect(cornerRadius: 12))
                .shadow(color: .black.opacity(note.hasCover ? 0.12 : 0), radius: 4, y: 1)
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
                    Text("Thấp").tag(140.0)
                    Text("Vừa").tag(200.0)
                    Text("Cao").tag(280.0)
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

}
