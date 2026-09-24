import Foundation

public struct EqPreset: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let gains: [Float] // 10 values in dB (-12 to +12)

    public init(name: String, gains: [Float]) {
        self.name = name
        self.gains = gains
    }
}

public enum EQPresetConstants {
    public static let frequencies: [Float] = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

    public static let presets: [String: EqPreset] = [
        "Flat": EqPreset(name: "Flat", gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
        "Bass Boost": EqPreset(name: "Bass Boost", gains: [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
        "Bass Reducer": EqPreset(name: "Bass Reducer", gains: [-6, -5, -4, -2, 0, 0, 0, 0, 0, 0]),
        "Treble Boost": EqPreset(name: "Treble Boost", gains: [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]),
        "Vocal Boost": EqPreset(name: "Vocal Boost", gains: [-2, -1, 0, 2, 4, 4, 3, 1, 0, -1]),
        "Rock": EqPreset(name: "Rock", gains: [5, 4, 2, -1, -2, -1, 2, 4, 5, 5]),
        "Pop": EqPreset(name: "Pop", gains: [-1, 2, 4, 4, 2, 0, -1, 2, 4, 4]),
        "Electronic": EqPreset(name: "Electronic", gains: [5, 4, 1, 0, -2, 1, 2, 4, 5, 5]),
        "Classical": EqPreset(name: "Classical", gains: [4, 3, 2, 1, -1, -1, 0, 2, 3, 4]),
        "Jazz": EqPreset(name: "Jazz", gains: [3, 2, 1, 2, -1, -1, 0, 2, 3, 3]),
        "Acoustic": EqPreset(name: "Acoustic", gains: [3, 2, 1, 1, 2, 2, 3, 4, 3, 2])
    ]

    public static let presetList: [EqPreset] = [
        presets["Flat"]!,
        presets["Bass Boost"]!,
        presets["Bass Reducer"]!,
        presets["Treble Boost"]!,
        presets["Vocal Boost"]!,
        presets["Rock"]!,
        presets["Pop"]!,
        presets["Electronic"]!,
        presets["Classical"]!,
        presets["Jazz"]!,
        presets["Acoustic"]!
    ]
}
