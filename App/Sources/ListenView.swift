import SwiftUI
import KXSFCore

struct ListenView: View {
    @ObservedObject var player: AudioPlayerService
    @ObservedObject var liveShow: LiveShowStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [.black, .black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 340 : 390)
            .ignoresSafeArea(edges: .top)
            .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 16 : 24) {
                    Image("KXSFLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? 220 : 280)
                        .aspectRatio(1, contentMode: .fit)
                        .shadow(color: .black.opacity(0.65), radius: 24, y: 16)
                        .accessibilityLabel("KXSF 102.5 FM, San Francisco Community Radio")

                    statusPanel

                    playbackControl
                }
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 12 : 24)
                .padding(.horizontal, 20)
                .padding(.bottom, 104)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var statusPanel: some View {
        Group {
            if player.state.isPlaying, let currentShow = liveShow.currentShow {
                HStack(spacing: 16) {
                    ShowArtwork(show: currentShow, size: 104)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOW PLAYING")
                            .font(.caption2.weight(.bold))
                            .tracking(1.1)
                            .foregroundStyle(KXSFColors.signalYellow)
                        Text(currentShow.name)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                            .foregroundStyle(.white)
                        if let hostName = currentShow.hostName {
                            Text("with \(hostName)")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.72))
                        }
                        Text(currentShow.timeRange)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(KXSFColors.signalYellow)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("now-playing-card")
                .accessibilityLabel("Now playing: \(currentShow.name), \(currentShow.hostName ?? "host unavailable"), \(currentShow.timeRange)")
            } else {
                VStack(spacing: 6) {
                    Text(statusEyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(KXSFColors.signalYellow)
                    Text(statusTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                }
                .accessibilityIdentifier("playback-status")
                .accessibilityLabel(player.state.isPlaying ? "Live on KXSF" : statusTitle)
            }
        }
        .frame(maxWidth: .infinity, minHeight: statusContentHeight, maxHeight: statusContentHeight)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("playback-status-card")
    }

    private var playbackControl: some View {
        playbackButton
            .buttonStyle(.plain)
            .background(.ultraThinMaterial, in: Circle())
            .overlay { Circle().stroke(.white.opacity(0.18), lineWidth: 1) }
            .shadow(color: .black.opacity(0.34), radius: 16, y: 8)
    }

    private var playbackButton: some View {
        Button(action: player.togglePlayback) {
            Group {
                if player.state == .loading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: player.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 38, weight: .bold))
                }
            }
            .frame(width: 108, height: 108)
        }
        .tint(player.state.isPlaying ? KXSFColors.signalRed : KXSFColors.signalYellow)
        .accessibilityIdentifier("playback-control")
        .accessibilityLabel(playbackControlLabel)
    }

    private var playbackControlLabel: String {
        switch player.state {
        case .loading: "Cancel connection to KXSF"
        case .playing: "Pause KXSF live stream"
        case .idle, .failed: "Play KXSF live stream"
        }
    }

    private var statusEyebrow: String {
        switch player.state {
        case .playing: "ON AIR NOW"
        case .loading: "CONNECTING"
        case .failed: "STREAM STATUS"
        case .idle: "SAN FRANCISCO"
        }
    }

    private var statusTitle: String {
        switch player.state {
        case .idle: "Listen Now"
        case .loading: "Connecting to KXSF…"
        case .playing: liveShow.showName ?? "Live on KXSF"
        case .failed: "Stream unavailable"
        }
    }

    private var statusContentHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 148 : 104
    }
}

struct ShowArtwork: View {
    let show: KXSFShow
    let size: CGFloat

    var body: some View {
        Group {
            if let artworkURL = show.artworkURL {
                AsyncImage(url: artworkURL, transaction: Transaction(animation: .default)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        artworkFallback
                    }
                }
            } else {
                artworkFallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var artworkFallback: some View {
        ZStack {
            LinearGradient(
                colors: [KXSFColors.signalRed, Color(red: 0.12, green: 0.08, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(KXSFColors.signalYellow)
        }
    }
}
