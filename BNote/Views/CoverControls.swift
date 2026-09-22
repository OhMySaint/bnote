import AppKit
import SwiftData
import SwiftUI

/// Cover picker used by the inspector, so a cover can be set without hunting
/// for the hover-only buttons on the page.
struct CoverControls: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if note.hasCover {
                CoverView(note: note, cornerRadius: 6)
                    .frame(height: 64)
            }
            HStack(spacing: 6) {
                Button("Choose picture…") { pickFile() }
                Button("Paste") { paste() }
                    .help("Paste the picture on the clipboard")
                if note.hasCover {
                    Button("Remove") { remove() }
                }
            }
            .controlSize(.small)
            HStack(spacing: 4) {
                ForEach(CoverStyle.allCases) { style in
                    Button {
                        note.coverData = nil
                        note.coverStyle = style.rawValue
                        note.touch()
                    } label: {
                        style.gradient
                            .frame(width: 26, height: 20)
                            .clipShape(.rect(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(note.coverStyle == style.rawValue ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .help(style.label)
                }
            }
            if note.hasCover {
                Picker("Height", selection: $note.coverHeight) {
                    Text("Short").tag(140.0)
                    Text("Medium").tag(200.0)
                    Text("Cao").tag(280.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    static func pick(into note: Note) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.prompt = "Set as cover"
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        apply(image, to: note)
    }

    static func pasteInto(_ note: Note) {
        guard let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage else {
            NSSound.beep()
            return
        }
        apply(image, to: note)
    }

    static func apply(_ image: NSImage, to note: Note) {
        note.coverData = image.coverData()
        note.coverStyle = ""
        note.coverOffset = 0.5
        note.touch()
    }

    static func remove(from note: Note) {
        note.coverData = nil
        note.coverStyle = ""
        note.touch()
    }

    private func pickFile() { Self.pick(into: note) }
    private func paste() { Self.pasteInto(note) }
    private func remove() { Self.remove(from: note) }
}
