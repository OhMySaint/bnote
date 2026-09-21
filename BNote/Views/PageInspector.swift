import SwiftUI

/// Right-hand inspector: document outline on one tab, page setup on the other.
struct InspectorPanel: View {
    @ObservedObject var controller: DocumentController
    @Binding var tab: InspectorTab

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(InspectorTab.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(10)

            Divider()

            switch tab {
            case .outline: OutlinePanel(controller: controller)
            case .page: PageSetupPanel(controller: controller)
            }
        }
        .frame(width: 236)
        .background(.regularMaterial)
    }
}

enum InspectorTab: String, CaseIterable, Identifiable {
    case outline, page

    var id: String { rawValue }

    var label: String {
        switch self {
        case .outline: "Mục lục"
        case .page: "Trang"
        }
    }
}

struct PageSetupPanel: View {
    @ObservedObject var controller: DocumentController
    @State private var showCustomMargins = false

    private var unit: MeasurementUnit { Unit.current }
    private var sliderRange: ClosedRange<Double> { unit == .inch ? 0.25...2.0 : 0.5...5.0 }
    private var sliderStep: Double { unit == .inch ? 0.125 : 0.25 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("Khổ giấy") {
                    Picker("", selection: paperBinding) {
                        ForEach(Paper.allCases) { paper in
                            Text(paper.label).tag(paper)
                        }
                    }
                    .labelsHidden()
                    Text(controller.config.paper.sizeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                section("Hướng giấy") {
                    Picker("", selection: orientationBinding) {
                        ForEach(PageOrientation.allCases) { orientation in
                            Text(orientation.label).tag(orientation)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                section("Lề (\(unit.label))") {
                    presetCards
                    marginSlider("Ngang", value: horizontalMargin, symbol: "arrow.left.and.right")
                    marginSlider("Dọc", value: verticalMargin, symbol: "arrow.up.and.down")
                    DisclosureGroup("Tùy chỉnh từng cạnh", isExpanded: $showCustomMargins) {
                        Grid(horizontalSpacing: 8, verticalSpacing: 6) {
                            GridRow {
                                marginField("Trên", \.top)
                                marginField("Dưới", \.bottom)
                            }
                            GridRow {
                                marginField("Trái", \.left)
                                marginField("Phải", \.right)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .font(.caption)
                    Text("Mặc định cho trang mới đặt trong Cài đặt (⌘,). Bật thước hoặc đường biên lề để kéo trực tiếp.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Hiển thị") {
                    Toggle("Trang giấy rời (bóng, khe giữa trang)", isOn: Binding(
                        get: { !controller.canvasOptions.continuous },
                        set: { controller.canvasOptions.continuous = !$0 }
                    ))
                    Toggle("Thước kẻ", isOn: optionBinding(\.showRuler))
                    Toggle("Lưới ô vuông", isOn: optionBinding(\.showGrid))
                    Toggle("Đường biên lề", isOn: optionBinding(\.showMarginGuides))
                }

                section("Thu phóng") {
                    Toggle("Vừa chiều rộng cửa sổ", isOn: Binding(
                        get: { controller.canvasOptions.fitWidth },
                        set: { on in
                            if on { controller.zoomToFitWidth() } else { controller.setZoom(controller.effectiveZoom) }
                        }
                    ))
                    HStack {
                        Slider(value: zoomBinding, in: 0.5...2.5)
                            .disabled(controller.canvasOptions.fitWidth)
                        Text("\(Int((controller.effectiveZoom * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    Button("Về 100%") { controller.setZoom(1) }
                        .buttonStyle(.link)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Margin controls

    /// One-click presets drawn as tiny page diagrams, the way Notion offers
    /// layouts instead of numbers.
    private var presetCards: some View {
        HStack(spacing: 6) {
            ForEach(MarginPreset.all) { preset in
                let selected = controller.config.margins == preset.margins
                Button {
                    applyMargins(preset.margins)
                } label: {
                    VStack(spacing: 4) {
                        MarginThumbnail(margins: preset.margins, paper: controller.config)
                            .frame(width: 34, height: 44)
                        Text(preset.shortLabel)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.04),
                        in: .rect(cornerRadius: 7)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(selected ? Color.accentColor : .clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(preset.label)
            }
        }
    }

    private func marginSlider(_ label: String, value: Binding<Double>, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            Slider(value: value, in: sliderRange, step: sliderStep)
            Text(Unit.format(value.wrappedValue * unit.points))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .help("Lề \(label.lowercased())")
    }

    /// Left and right together.
    private var horizontalMargin: Binding<Double> {
        Binding(
            get: { controller.config.margins.left / unit.points },
            set: { value in
                var margins = controller.config.margins
                margins.left = value * unit.points
                margins.right = value * unit.points
                applyMargins(margins)
            }
        )
    }

    /// Top and bottom together.
    private var verticalMargin: Binding<Double> {
        Binding(
            get: { controller.config.margins.top / unit.points },
            set: { value in
                var margins = controller.config.margins
                margins.top = value * unit.points
                margins.bottom = value * unit.points
                applyMargins(margins)
            }
        )
    }

    private func applyMargins(_ margins: PageMargins) {
        var config = controller.config
        config.margins = margins
        config.clampMargins()
        controller.config = config
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func marginField(_ label: String, _ keyPath: WritableKeyPath<PageMargins, CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextField(
                "",
                value: Binding(
                    get: { controller.config.margins[keyPath: keyPath] / unit.points },
                    set: { newValue in
                        var config = controller.config
                        config.margins[keyPath: keyPath] = max(0, newValue) * unit.points
                        config.clampMargins()
                        controller.config = config
                    }
                ),
                format: .number.precision(.fractionLength(0...2))
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 74)
        }
    }

    private var paperBinding: Binding<Paper> {
        Binding(
            get: { controller.config.paper },
            set: { controller.config.paper = $0 }
        )
    }

    private var orientationBinding: Binding<PageOrientation> {
        Binding(
            get: { controller.config.orientation },
            set: {
                var config = controller.config
                config.orientation = $0
                config.clampMargins()
                controller.config = config
            }
        )
    }

    private var zoomBinding: Binding<Double> {
        Binding(
            get: { controller.canvasOptions.fitWidth ? controller.effectiveZoom : controller.canvasOptions.zoom },
            set: { controller.setZoom($0) }
        )
    }

    private func optionBinding(_ keyPath: WritableKeyPath<CanvasOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { controller.canvasOptions[keyPath: keyPath] },
            set: { controller.canvasOptions[keyPath: keyPath] = $0 }
        )
    }
}

/// Miniature sheet showing where the text box sits for a given set of margins.
private struct MarginThumbnail: View {
    let margins: PageMargins
    let paper: PageConfig

    var body: some View {
        GeometryReader { geometry in
            let scaleX = geometry.size.width / paper.size.width
            let scaleY = geometry.size.height / paper.size.height
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(.separator, lineWidth: 0.5))
                Rectangle()
                    .fill(Color.accentColor.opacity(0.35))
                    .frame(
                        width: max(2, (paper.size.width - margins.left - margins.right) * scaleX),
                        height: max(2, (paper.size.height - margins.top - margins.bottom) * scaleY)
                    )
                    .offset(x: margins.left * scaleX, y: margins.top * scaleY)
            }
        }
    }
}
