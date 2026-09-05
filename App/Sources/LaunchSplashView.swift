import SwiftUI

/// Full anniversary poster held long enough to read before the main app appears.
/// Apple's system launch screen is cream-only (it cannot safely show this poster
/// without cropping), so the readable art lives here for a short timed beat.
struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            Image("LaunchPoster")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 18)
                .accessibilityLabel("KXSF 8th Anniversary Fundraiser poster for 102.5 FM San Francisco Community Radio")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("LaunchBackground").ignoresSafeArea())
    }
}

#Preview {
    LaunchSplashView()
}
