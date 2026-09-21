import SwiftUI

/// Shared UI state that menus need to reflect with a check mark.
final class AppUIState: ObservableObject {
    static let shared = AppUIState()
    @Published var focusMode = false
    @Published var showInspector = true
}

/// Preferences (⌘,): defaults applied to new pages and the canvas at launch.
struct SettingsView: View {
    @AppStorage(Defaults.unitKey) private var unitRaw = MeasurementUnit.inch.rawValue
    @AppStorage(Defaults.marginKey) private var marginPoints = 54.0
    @AppStorage(Defaults.paperKey) private var paperRaw = Paper.a4.rawValue
    @AppStorage(Defaults.orientationKey) private var orientationRaw = PageOrientation.portrait.rawValue
    @AppStorage(Defaults.fitWidthKey) private var fitWidth = true
    @AppStorage(Defaults.rulerKey) private var showRuler = false
    @AppStorage(Defaults.gridKey) private var showGrid = false
    @AppStorage(Defaults.guidesKey) private var showGuides = false
    @AppStorage(Defaults.continuousKey) private var continuous = true

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .inch }

    var body: some View {
        Form {
            Section("Đơn vị đo") {
                Picker("Đơn vị", selection: $unitRaw) {
                    ForEach(MeasurementUnit.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("Trang mới") {
                Picker("Khổ giấy", selection: $paperRaw) {
                    ForEach(Paper.allCases) { Text("\($0.label) — \($0.sizeLabel)").tag($0.rawValue) }
                }
                Picker("Hướng giấy", selection: $orientationRaw) {
                    ForEach(PageOrientation.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Lề bốn cạnh")
                    Slider(
                        value: Binding(get: { marginPoints / unit.points }, set: { marginPoints = $0 * unit.points }),
                        in: unit == .inch ? 0.25...2.0 : 0.5...5.0,
                        step: unit == .inch ? 0.125 : 0.25
                    )
                    Text(Unit.format(marginPoints, unit: unit))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
                Text("Áp dụng cho trang tạo sau này; trang đang có chỉnh riêng trong bảng Trang.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hiển thị khi mở app") {
                Picker("Kiểu trang", selection: $continuous) {
                    Text("Liên tục (kiểu Notion)").tag(true)
                    Text("Trang giấy rời").tag(false)
                }
                Toggle("Vừa chiều rộng cửa sổ", isOn: $fitWidth)
                Toggle("Thước kẻ", isOn: $showRuler)
                Toggle("Lưới ô vuông", isOn: $showGrid)
                Toggle("Đường biên lề", isOn: $showGuides)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 6)
    }
}
