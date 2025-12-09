import SwiftUI

enum SerenelyTheme {

    // MARK: - Colors
    static let accent = Color("AccentColor")
    static let primaryStart = Color("PrimaryStart")
    static let primaryEnd = Color("PrimaryEnd")
    static let bubble = Color("Bubble")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")

    // MARK: - Gradients
    static let backgroundGradient = LinearGradient(
        colors: [primaryStart, primaryEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typography
    enum Font {
        static let title = SwiftUI.Font.system(size: 24, weight: .bold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 16, weight: .regular, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 13, weight: .medium, design: .rounded)
    }

    // MARK: - Components

    struct BubbleStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(SerenelyTheme.bubble)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(SerenelyTheme.accent.opacity(0.4), lineWidth: 1)
                        )
                )
                .shadow(color: SerenelyTheme.accent.opacity(0.2), radius: 6)
        }
    }

    struct GlowingButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(SerenelyTheme.accent)
                .cornerRadius(14)
                .shadow(color: SerenelyTheme.accent.opacity(configuration.isPressed ? 0.4 : 0.7),
                        radius: configuration.isPressed ? 4 : 10)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }

    struct TextFieldStyle: ViewModifier {
        func body(content: Content) -> some View {
            content
                .padding(12)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SerenelyTheme.accent.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(.white)
        }
    }

    struct CapsuleChip: View {
        let title: String
        let active: Bool
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(SerenelyTheme.Font.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: active ? [SerenelyTheme.accent.opacity(0.55), SerenelyTheme.bubble.opacity(0.6)] : [SerenelyTheme.bubble.opacity(0.7), SerenelyTheme.bubble.opacity(0.5)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(active ? SerenelyTheme.accent.opacity(0.9) : Color.white.opacity(0.15), lineWidth: active ? 1.5 : 1)
                    )
                    .clipShape(Capsule())
                    .shadow(color: active ? SerenelyTheme.accent.opacity(0.35) : Color.clear, radius: active ? 8 : 0)
                    .animation(.easeOut(duration: 0.18), value: active)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Global Modifiers (зручно викликати коротко)
extension View {
    func serenelyBubble() -> some View {
        modifier(SerenelyTheme.BubbleStyle())
    }

    func serenelyTextField() -> some View {
        modifier(SerenelyTheme.TextFieldStyle())
    }
    
    func glassCard(corner: CGFloat = 20) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .background(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .blur(radius: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(LinearGradient(
                                colors: [SerenelyTheme.accent.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
            )
            .shadow(color: SerenelyTheme.accent.opacity(0.15), radius: 10, x: 0, y: 6)
    }
}
