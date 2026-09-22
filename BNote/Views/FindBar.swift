import SwiftUI

/// The ⌘F strip under the toolbar: search field, hit counter, previous / next,
/// optional replace row. Enter jumps to the next hit, ⇧Enter to the previous,
/// Escape closes.
struct FindBar: View {
    @ObservedObject var controller: DocumentController
    @ObservedObject var model: FindModel

    private enum Field { case query, replacement }
    @FocusState private var focused: Field?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                searchField
                Text(model.summary)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(model.hasMatches || model.query.isEmpty ? .secondary : Color.red)
                    .frame(minWidth: 52, alignment: .leading)

                Toggle(isOn: $model.caseSensitive) {
                    Text("Aa")
                        .font(.system(size: 11, weight: .semibold))
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Match case")

                HStack(spacing: 0) {
                    Button { controller.findPrevious() } label: { Image(systemName: "chevron.up") }
                        .help("Previous match (⇧⌘G)")
                    Button { controller.findNext() } label: { Image(systemName: "chevron.down") }
                        .help("Next match (⌘G)")
                }
                .controlSize(.small)
                .disabled(!model.hasMatches)

                Toggle(isOn: $model.showReplace) {
                    Text("Replace")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                .help("Show the replace field (⌥⌘F)")

                Spacer()

                Button("Done") { controller.hideFind() }
                    .controlSize(.small)
                    .keyboardShortcut(.cancelAction)
            }

            if model.showReplace {
                HStack(spacing: 8) {
                    TextField("Replace with", text: $model.replacement)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(maxWidth: 320)
                        .focused($focused, equals: .replacement)
                        .onSubmit { controller.replaceCurrentMatch() }
                    Button("Replace") { controller.replaceCurrentMatch() }
                        .controlSize(.small)
                        .disabled(!model.hasMatches)
                    Button("Replace all") { controller.replaceAllMatches() }
                        .controlSize(.small)
                        .disabled(!model.hasMatches)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onAppear { focused = .query }
        .onChange(of: model.focusRequest) { _, _ in
            focused = model.showReplace && focused == .replacement ? .replacement : .query
        }
        .onChange(of: model.showReplace) { _, on in
            if on { focused = .replacement }
        }
        .onChange(of: model.query) { _, _ in controller.findQueryChanged() }
        .onChange(of: model.caseSensitive) { _, _ in controller.findQueryChanged() }
        .onExitCommand { controller.hideFind() }
    }

    private var searchField: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Find in page", text: $model.query)
                .textFieldStyle(.plain)
                .focused($focused, equals: .query)
                .onSubmit { controller.findNext() }
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.shift) else { return .ignored }
                    controller.findPrevious()
                    return .handled
                }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: 320)
    }
}
