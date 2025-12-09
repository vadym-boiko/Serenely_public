import SwiftUI

struct PortraitView: View {
    @EnvironmentObject var vm: TherapyChatViewModel
    @EnvironmentObject var locale: LocalizationManager
    @State private var showResetConfirm = false
    @State private var expandSummary = false

    var body: some View {
        ZStack {
            // Background gradient using theme
            SerenelyTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                // Головна колонка: зменшив міжсекційний відступ, щоб не було «повітря»
                VStack(alignment: .leading, spacing: 12) {
                    lastSessionHighlightsSection
                    summarySection
                    focusAreasSection
                    helpfulStrategiesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .foregroundStyle(SerenelyTheme.textPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { languageSwitcher }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label(L10n.t("portrait.clear", "Clear"), systemImage: "trash")
                }
            }
        }
        .alert(L10n.t("portrait.clear_confirm_title", "Clear portrait?"), isPresented: $showResetConfirm) {
            Button(L10n.t("common.cancel", "Cancel"), role: .cancel) {}
            Button(L10n.t("portrait.clear_confirm", "Clear"), role: .destructive) { vm.clearPortrait() }
        } message: {
            Text(L10n.t("portrait.clear_confirm_message", "This will delete saved summary, focus areas, strategies, weights and stats. This action cannot be undone."))
        }
    }
}

// MARK: - Components
extension PortraitView {
    // Блок «Нове за останню сесію» (без змін по суті)
    @ViewBuilder
    var lastSessionHighlightsSection: some View {
        if hasHighlights(vm.lastSessionHighlights) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("portrait.last_session", "New in last session")).font(SerenelyTheme.Font.title)
                summaryUpdateView
                newFocusAreasView
                newStrategiesView
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: SerenelyTheme.accent.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }

    @ViewBuilder
    var languageSwitcher: some View {
        HStack(spacing: 4) {
            langPill(title: "UK", lang: .uk, isActive: locale.language == .uk)
            langPill(title: "EN", lang: .en, isActive: locale.language == .en)
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func langPill(title: String, lang: AppLanguage, isActive: Bool) -> some View {
        Button {
            locale.set(lang)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? SerenelyTheme.accent : Color.clear)
                .clipShape(Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var summaryUpdateView: some View {
        if vm.lastSessionHighlights.summaryUpdated {
            HStack(spacing: 8) {
                Badge(text: L10n.t("portrait.summary_updated", "Summary updated"))
                if let preview = vm.lastSessionHighlights.summaryPreview {
                    Text(preview)
                        .font(SerenelyTheme.Font.caption)
                        .foregroundStyle(SerenelyTheme.textSecondary)
                        .lineLimit(2)
                }
            }
        }
    }

    @ViewBuilder
    var newFocusAreasView: some View {
        if !vm.lastSessionHighlights.newFocusAreas.isEmpty {
            Label(L10n.t("portrait.focuses", "Focuses:"), systemImage: "target").font(SerenelyTheme.Font.body)
            WrapChips(items: vm.lastSessionHighlights.newFocusAreas)
        }
    }

    @ViewBuilder
    var newStrategiesView: some View {
        if !vm.lastSessionHighlights.newStrategies.isEmpty {
            Label(L10n.t("portrait.strategies", "Strategies:"), systemImage: "lightbulb").font(SerenelyTheme.Font.body)
            WrapChips(items: vm.lastSessionHighlights.newStrategies)
        }
    }


    // Загальний портрет (без змін)
    var summarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("portrait.overall", "Overall portrait")).font(SerenelyTheme.Font.title)
                Spacer()
                Text(vm.portrait.lastUpdated, style: .date)
                    .environment(\.locale, portraitLocale)
                    .font(SerenelyTheme.Font.caption)
                    .foregroundStyle(SerenelyTheme.textSecondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(isSummaryEffectivelyEmpty ? L10n.t("portrait.initial_insufficient", "Initial session: not enough data yet.") : vm.portrait.summary)
                    .font(SerenelyTheme.Font.body)
                    .foregroundStyle(SerenelyTheme.textPrimary)
                    .lineLimit(expandSummary ? nil : 4)
                    .animation(.easeInOut(duration: 0.2), value: expandSummary)
                if !isSummaryEffectivelyEmpty {
                    Button(expandSummary ? L10n.t("common.collapse", "Collapse") : L10n.t("common.show_more", "Show more")) { expandSummary.toggle() }
                        .font(SerenelyTheme.Font.caption)
                        .foregroundStyle(SerenelyTheme.textPrimary)
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    // Фокус-області: прибрав потенційні великі відступи
    var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("portrait.focus_areas", "Focus areas")).font(SerenelyTheme.Font.title)
            if vm.portrait.focusAreas.isEmpty {
                Text(L10n.t("common.empty", "No items yet"))
                    .foregroundStyle(SerenelyTheme.textSecondary)
                    .padding(.vertical, 4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                WrapChips(items: vm.portrait.focusAreas)
                    .padding(.top, 2)
            }
        }
    }

    // Корисні стратегії: тут був «великий провал». Перевів на LazyVGrid
    var helpfulStrategiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("portrait.helpful_strategies", "Helpful strategies")).font(SerenelyTheme.Font.title)
            if vm.portrait.helpfulStrategies.isEmpty {
                Text(L10n.t("common.empty", "No items yet"))
                    .foregroundStyle(SerenelyTheme.textSecondary)
                    .padding(.vertical, 4)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                WrapChips(items: vm.portrait.helpfulStrategies)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Helper
    func hasHighlights(_ h: SessionHighlights) -> Bool {
        h.summaryUpdated
        || !h.newFocusAreas.isEmpty
        || !h.newStrategies.isEmpty
    }

    // MARK: - Local Component Views

    private struct Badge: View {
        let text: String
        var body: some View {
            Text(text)
                .font(SerenelyTheme.Font.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SerenelyTheme.bubble)
                .clipShape(Capsule())
        }
    }

    private struct DeltaRow: View {
        let name: String
        let delta: Double
        let up: Bool
        var body: some View {
            HStack {
                Image(systemName: up ? "arrow.up" : "arrow.down")
                    .foregroundStyle(up ? SerenelyTheme.accent : .orange)
                Text(name).font(SerenelyTheme.Font.body)
                Spacer()
                Text(String(format: "%+.2f", delta))
                    .font(SerenelyTheme.Font.caption)
                    .foregroundStyle(SerenelyTheme.textSecondary)
            }
        }
    }

    // ✅ НОВА реалізація чіпів: жодних GeometryReader/alignmentGuide
    private struct WrapChips: View {
        let items: [String]
        // adaptive сітка: підлаштовується під ширину екрану
        private var cols: [GridItem] {
            [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .leading)]
        }
        var body: some View {
            LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(SerenelyTheme.Font.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(SerenelyTheme.bubble)
                        .clipShape(Capsule())
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Helpers
extension PortraitView {
    private var portraitLocale: Locale {
        switch locale.language {
        case .en: return Locale(identifier: "en_US")
        case .uk: return Locale(identifier: "uk_UA")
        }
    }

    private var isSummaryEffectivelyEmpty: Bool {
        let s = vm.portrait.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return true }
        let placeholders = [
            L10n.t("portrait.no_summary", "No saved summaries yet."),
            L10n.t("portrait.initial_insufficient", "Initial session: not enough data yet.")
        ]
        return placeholders.contains(s)
    }
}
