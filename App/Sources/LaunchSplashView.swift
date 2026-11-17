import SwiftUI

/// Timed in-app splash for iPhone and iPad: solid black, with the official KXSF
/// station logo large and centered. The logo is only ever scaled to fit (aspect
/// preserved), so it is never cropped or distorted. The system launch screen is
/// configured separately in project.yml and is untouched by this view.
struct LaunchSplashView: View {
    /// Test-only: report whether app loading has begun behind the splash.
    var loadProbeValue: String?

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height) * 0.72
            ZStack {
                Color.black.ignoresSafeArea()

                Image("KXSFLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .accessibilityHidden(true)

                if let loadProbeValue {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement()
                        .accessibilityIdentifier("launch-splash-load-state")
                        .accessibilityValue(loadProbeValue)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.black.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("KXSF 102.5 FM San Francisco Community Radio")
        .accessibilityIdentifier("launch-splash")
    }
}

#Preview {
    LaunchSplashView()
}
