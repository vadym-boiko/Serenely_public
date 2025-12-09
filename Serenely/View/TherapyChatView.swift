



import SwiftUI

struct TherapyChatView: View {
    @EnvironmentObject var vm: TherapyChatViewModel
    @EnvironmentObject var locale: LocalizationManager
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            // Background gradient using theme
            SerenelyTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(vm.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                            
                            // Індикатор обдумування
                            if vm.isGeneratingResponse {
                                thinkingIndicator()
                                    .id("THINKING_INDICATOR")
                            }
                            
                            // "якір", щоб легше скролити в кінець
                            Color.clear
                                .frame(height: 1)
                                .id("BOTTOM_ANCHOR")
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    // При перетягуванні списку — ховаємо клавіатуру
                    .gesture(
                        DragGesture().onChanged { _ in hideKeyboard() }
                    )
                    // iOS 16+: автоматично ховає клавіатуру при скролі
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollProxy = proxy }
                }
                // Тап по будь-якому вільному місцю в області скролу — ховає клавіатуру
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }

                // Modern input field using theme
                inputSection()

                // End session button using theme
                Button {
                    Task { await vm.endSession() }
                } label: {
                    Text(vm.isFinalizing ? L10n.t("chat.generating", "Generating summary…") : L10n.t("chat.end", "End session"))
                }
                .buttonStyle(SerenelyTheme.GlowingButtonStyle())
                .padding(.horizontal)
                .padding(.bottom, 16)
                .disabled(vm.isFinalizing)
            }
        }
        .foregroundStyle(SerenelyTheme.textPrimary)
        .onAppear { KeyboardWarmer.shared.prewarm() }
        .sheet(isPresented: $vm.showSummarySheet) {
            SummarySheetView(
                editedSummary: $vm.sessionSummary,
                suggestedTasks: $vm.suggestedTasks,
                onConfirm: { editedSummary, thumbsUp, flags, feedbackTasks, saved in
                    vm.confirmSummaryAndUpdatePortrait(
                        editedSummary: editedSummary,
                        thumbsUp: thumbsUp,
                        flags: flags,
                        with: feedbackTasks,
                        saved: saved
                    )
                }
            )
        }
        .navigationTitle(L10n.t("app.title", "Serenely"))
        // Тап в будь-якому місці поза інпутом — ховає клавіатуру
        .onTapGesture { hideKeyboard() }
        // Автопрокрутка донизу при нових повідомленнях або появі індикатора
        .onChange(of: vm.messages.count) { _, _ in
            scrollToBottom(animated: true)
        }
        .onChange(of: vm.isGeneratingResponse) { _, newValue in
            if newValue {
                scrollToBottom(animated: true)
            }
        }
        .onChange(of: locale.language) { _, _ in
            vm.startNewSession()
        }
    }
}

// MARK: - Components
extension TherapyChatView {
    @ViewBuilder
    func inputSection() -> some View {
        HStack(spacing: 12) {
            TextField(L10n.t("chat.input.placeholder", "Type how you feel…"), text: $vm.currentInput, axis: .vertical)
                .font(SerenelyTheme.Font.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: isInputFocused ? SerenelyTheme.accent.opacity(0.22) : Color.black.opacity(0.18), radius: isInputFocused ? 10 : 6, x: 0, y: 4)
                .focused($isInputFocused)

            Button {
                Task {
                    await vm.send()
                    hideKeyboard()
                    scrollToBottom(animated: true)
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(SerenelyTheme.accent)
                            .shadow(color: SerenelyTheme.accent.opacity(0.5), radius: 12, x: 0, y: 4)
                    )
            }
            .disabled(vm.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(vm.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            .animation(.easeOut(duration: 0.15), value: vm.currentInput.isEmpty)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = true }
        // Убираем общий фон бара, чтобы поле выглядело «плавающим» на градиенте
        // .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    func messageBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.sender == .user
        HStack(spacing: 0) {
            if isUser { Spacer(minLength: 0) }
            MessageBubbleView(text: msg.text, isFromUser: isUser)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.78,
                       alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 0) }
        }
        .padding(.horizontal, 2) // легкий дихаючий простір по краях
    }

    // Новий маленький компонент однієї бульбашки
    struct MessageBubbleView: View {
        let text: String
        let isFromUser: Bool

        var body: some View {
            Text(text)
                .font(SerenelyTheme.Font.body)
                .foregroundStyle(.white)
                .padding(16)
                .background(
                    Group {
                        if isFromUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                        } else {
                            // AI: скляний ефект з тонким внутрішнім штрихом
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                )
                .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }

    @ViewBuilder
    func thinkingIndicator() -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                // Анімовані крапки
                ForEach(0..<3, id: \.self) { index in
                    AnimatedDot(delay: Double(index) * 0.2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
            .frame(maxWidth: UIScreen.main.bounds.width * 0.78, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
    }
    
    // Окремий компонент для анімованої крапки
    struct AnimatedDot: View {
        let delay: Double
        @State private var isAnimating = false
        
        var body: some View {
            Circle()
                .fill(SerenelyTheme.accent)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.4)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                    ) {
                        isAnimating = true
                    }
                }
        }
    }

    func scrollToBottom(animated: Bool) {
        guard let proxy = scrollProxy else { return }
        withAnimation(animated ? .easeOut(duration: 0.2) : nil) {
            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
        }
    }
}

// MARK: - Keyboard helper
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
