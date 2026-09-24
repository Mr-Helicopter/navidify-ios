import SwiftUI
import NavidifyKit

public struct EqualizerView: View {
    @Bindable var engine = AudioEngine.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // EQ Toggle
                        Toggle(isOn: $engine.isEQEnabled) {
                            Text("Equalizer")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .tint(Theme.green)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                        // Presets Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRESET")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Theme.textSubdued)
                                .padding(.horizontal, 20)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(EQPresetConstants.presetList) { preset in
                                        Button(action: {
                                            engine.selectedPresetName = preset.name
                                        }) {
                                            Text(preset.name)
                                                .font(.system(size: 13, weight: .medium))
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(engine.selectedPresetName == preset.name ? Theme.green : Theme.surfaceElevated)
                                                .foregroundColor(engine.selectedPresetName == preset.name ? .black : Theme.textPrimary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }

                        // 10 Frequency Sliders
                        VStack(spacing: 16) {
                            ForEach(0..<10, id: \.self) { idx in
                                HStack {
                                    Text(frequencyLabel(for: EQPresetConstants.frequencies[idx]))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Theme.textSecondary)
                                        .frame(width: 50, alignment: .leading)

                                    Slider(
                                        value: Binding(
                                            get: { engine.eqGains[idx] },
                                            set: {
                                                engine.eqGains[idx] = $0
                                                engine.selectedPresetName = "Custom"
                                            }
                                        ),
                                        in: -12...12,
                                        step: 0.5
                                    )
                                    .tint(Theme.green)
                                    .disabled(!engine.isEQEnabled)

                                    Text(String(format: "%+.1f dB", engine.eqGains[idx]))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(Theme.textSubdued)
                                        .frame(width: 55, alignment: .trailing)
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Audio Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.green)
                }
            }
        }
    }

    private func frequencyLabel(for freq: Float) -> String {
        if freq >= 1000 {
            return "\(Int(freq / 1000))kHz"
        } else {
            return "\(Int(freq))Hz"
        }
    }
}
