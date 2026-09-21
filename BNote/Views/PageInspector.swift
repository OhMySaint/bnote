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

                section("Lề (cm)") {
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
                    Menu("Lề đặt sẵn") {
                        ForEach(MarginPreset.all) { preset in
                            Button(preset.label) {
                                var config = controller.config
                                config.margins = preset.margins
                                config.clampMargins()
                                controller.config = config
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                }

                section("Hiển thị") {
                    Toggle("Thước kẻ", isOn: optionBinding(\.showRuler))
                    Toggle("Lưới ô vuông", isOn: optionBinding(\.showGrid))
                    Toggle("Đường biên lề", isOn: optionBinding(\.showMarginGuides))
                }

                section("Thu phóng") {
                    HStack {
                        Slider(value: zoomBinding, in: 0.5...2.0)
                        Text("\(Int(controller.canvasOptions.zoom * 100))%")
                            .font(.caption.monospacedDigit())
                            .frame(width: 40, alignment: .trailing)
                    }
                    Button("Về 100%") { controller.canvasOptions.zoom = 1 }
                        .buttonStyle(.link)
                }
            }
            .padding(14)
        }
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
                    get: { controller.config.margins[keyPath: keyPath] / Unit.centimeter },
                    set: { newValue in
                        var config = controller.config
                        config.margins[keyPath: keyPath] = max(0, newValue) * Unit.centimeter
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
            get: { controller.canvasOptions.zoom },
            set: { controller.canvasOptions.zoom = $0 }
        )
    }

    private func optionBinding(_ keyPath: WritableKeyPath<CanvasOptions, Bool>) -> Binding<Bool> {
        Binding(
            get: { controller.canvasOptions[keyPath: keyPath] },
            set: { controller.canvasOptions[keyPath: keyPath] = $0 }
        )
    }
}
