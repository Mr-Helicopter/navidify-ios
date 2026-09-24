import SwiftUI
import NavidifyKit

public struct ArtistDetailView: View {
    let artist: Artist
    @Bindable var appState = AppState.shared
    @State private var albums: [Album] = []
    @State private var isLoading = true

    public var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Artwork & Name
                    VStack(alignment: .center, spacing: 12) {
                        RemoteArtworkImage(coverArtId: artist.coverArt, size: 160, cornerRadius: 80)
                            .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)

                        Text(artist.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                    // Albums Header
                    Text("Albums")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 20)

                    if isLoading {
                        ProgressView().tint(Theme.green).frame(maxWidth: .infinity).padding(.top, 20)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(albums) { album in
                                NavigationLink(destination: AlbumDetailView(album: album)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        RemoteArtworkImage(coverArtId: album.coverArt, size: 160, cornerRadius: 6)
                                        Text(album.displayTitle)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.textPrimary)
                                            .lineLimit(1)
                                        if let year = album.year {
                                            Text(String(year))
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.textSubdued)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArtist()
        }
    }

    private func loadArtist() async {
        if let detailed = try? await appState.client.getArtist(id: artist.id),
           let albs = detailed.album {
            await MainActor.run {
                self.albums = albs
                self.isLoading = false
            }
        } else {
            await MainActor.run { self.isLoading = false }
        }
    }
}
