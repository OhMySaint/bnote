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
    @AppStorage(Defaults.fullWidthKey) private var fullWidth = false
    @AppStorage(Defaults.gridKey) private var showGrid = false
    @AppStorage(Defaults.guidesKey) private var showGuides = false
    @AppStorage(Defaults.continuousKey) private var continuous = true

    private var unit: MeasurementUnit { MeasurementUnit(rawValue: unitRaw) ?? .inch }

    var body: some View {
        Form {
            Section("Measurement units") {
                Picker("Units", selection: $unitRaw) {
                    ForEach(MeasurementUnit.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
            }

            Section("New page") {
                Picker("Paper size", selection: $paperRaw) {
                    ForEach(Paper.allCases) { Text("\($0.label) — \($0.sizeLabel)").tag($0.rawValue) }
                }
                Picker("Orientation", selection: $orientationRaw) {
                    ForEach(PageOrientation.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Margins")
                    Slider(
                        value: Binding(get: { marginPoints / unit.points }, set: { marginPoints = $0 * unit.points }),
                        in: unit == .inch ? 0.25...2.0 : 0.5...5.0,
                        step: unit == .inch ? 0.125 : 0.25
                    )
                    Text(Unit.format(marginPoints, unit: unit))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                }
                Text("Applies to pages created from now on; change existing pages in the Page inspector.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Defaults for new pages") {
                Picker("Page mode", selection: $continuous) {
                    Text("Continuous (Notion style)").tag(true)
                    Text("Paper pages").tag(false)
                }
                Toggle("Full width (text spans the window)", isOn: $fullWidth)
                Toggle("Grid", isOn: $showGrid)
                Toggle("Margin guides", isOn: $showGuides)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 6)
    }
}
