import SwiftUI

struct LaunchView: View {
    var onFinish: () -> Void = {}

    var body: some View {
        ZStack {
            SerenelyTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Text(L10n.t("app.title", "Serenely"))
                    .font(SerenelyTheme.Font.title)
                    .foregroundStyle(.white)

                Text(L10n.t("launch.tagline", "Personal reflection companion"))
                    .font(SerenelyTheme.Font.caption)
                    .foregroundStyle(.white.opacity(0.8))

                ProgressView()
                    .tint(SerenelyTheme.accent)
                    .padding(.top, 8)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                onFinish()
            }
        }
    }
}


