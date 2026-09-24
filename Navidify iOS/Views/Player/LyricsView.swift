import SwiftUI
import NavidifyKit

public struct LyricsView: View {
    let song: Song
    @Bindable var appState = AppState.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if appState.currentLyrics.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "quote.bubble")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textSubdued)
                        Text("No lyrics available for this song")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textSecondary)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                ForEach(appState.currentLyrics) { line in
                                    let isCurrent = isCurrentLine(line: line)
                                    Text(line.text)
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(isCurrent ? .white : Theme.textSubdued.opacity(0.6))
                                        .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                                        .animation(.easeInOut(duration: 0.2), value: isCurrent)
                                        .id(line.id)
                                        .onTapGesture {
                                            appState.engine.seek(to: line.time)
                                        }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 32)
                        }
                        .onChange(of: appState.engine.currentTime) { _, _ in
                            if let active = activeLine() {
                                withAnimation {
                                    proxy.scrollTo(active.id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lyrics")
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
        .task {
            await appState.fetchLyrics(for: song)
        }
    }

    private func isCurrentLine(line: ParsedLyricLine) -> Bool {
        guard let active = activeLine() else { return false }
        return active.id == line.id
    }

    private func activeLine() -> ParsedLyricLine? {
        let cur = appState.engine.currentTime
        return appState.currentLyrics.last(where: { $0.time <= cur })
    }
}
