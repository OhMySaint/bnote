import SwiftUI

/// Notion-style document outline: every heading, click to jump.
struct OutlinePanel: View {
    @ObservedObject var controller: DocumentController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if controller.outline.isEmpty {
                Spacer(minLength: 12)
                Text("Dùng kiểu Đầu mục 1–3 để tạo mục lục.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(controller.outline) { item in
                            Button {
                                controller.scrollToOutlineItem(item)
                            } label: {
                                Text(item.text)
                                    .font(item.level == 1 ? .callout.weight(.medium) : .caption)
                                    .foregroundStyle(item.level == 1 ? .primary : .secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .padding(.leading, CGFloat(item.level - 1) * 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
