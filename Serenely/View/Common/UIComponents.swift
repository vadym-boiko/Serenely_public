//
//  UIComponents.swift
//  Serenely
//
//  Created by Vadym on 05.10.2025.
//

import Foundation
import SwiftUI

// MARK: - Task Card
enum TaskCardMode { case full, summarySheet }

struct TaskCardView: View {
    @Binding var task: ActionTask
    let mode: TaskCardMode
    var usefulnessOnlyLMH: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            details
            controls
        }
        .glassCard(corner: 20)
        .animation(.easeOut(duration: 0.2), value: task.status)
        .animation(.easeOut(duration: 0.2), value: task.usefulness)
    }

    // MARK: Header
    @ViewBuilder private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(task.title)
                .font(SerenelyTheme.Font.title)
                .foregroundStyle(SerenelyTheme.textPrimary)
            Spacer()
            statusTag(task.status)
        }
    }

    // MARK: Details
    @ViewBuilder private var details: some View {
        if let d = task.details, !d.isEmpty {
            Text(d)
                .font(SerenelyTheme.Font.body)
                .foregroundStyle(SerenelyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Controls switcher
    @ViewBuilder private var controls: some View {
        switch mode { case .full: fullControls; case .summarySheet: summarySheetControls }
    }

    // MARK: Full mode
    private var fullControls: some View {
        // Removed usefulness rating chips from TasksView cards
        EmptyView()
    }

    // MARK: SummarySheet mode
    private var summarySheetControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                SerenelyTheme.CapsuleChip(title: "⏭ " + L10n.t("common.skip", "Skip"), active: task.status == .skipped) { task.status = .skipped }
                SerenelyTheme.CapsuleChip(title: "➕ " + L10n.t("common.add", "Add"), active: task.status == .pending) { task.status = .pending }
            }
            // Usefulness LMH chips removed from summary sheet
        }
        .onAppear {
            if task.status == .notSet { task.status = .skipped }
            // usefulnessOnlyLMH defaulting removed
        }
    }

    // MARK: Status Tag
    @ViewBuilder
    private func statusTag(_ status: TaskStatus) -> some View {
        let (text, bg): (String, Color) = {
            switch status {
            case .pending, .notSet: return (L10n.t("status.pending", "Pending"), .yellow.opacity(0.28))
            case .done:             return (L10n.t("status.done", "Done"), .green.opacity(0.28))
            case .skipped:          return ("", .clear)
            }
        }()
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(bg)
            .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))
            .clipShape(Capsule())
            .foregroundStyle(.white)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(SerenelyTheme.Font.title)
            if let s = subtitle, !s.isEmpty {
                Text(s)
                    .font(SerenelyTheme.Font.caption)
                    .foregroundStyle(SerenelyTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty State
struct EmptyState: View {
    let iconName: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 44))
                .padding(.bottom, 6)
            Text(title)
                .font(SerenelyTheme.Font.title)
            Text(message)
                .font(SerenelyTheme.Font.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(SerenelyTheme.textSecondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Task List Wrapper (removed)
// TaskListView полностью удалён. Используйте напрямую ForEach + TaskCardView.

// MARK: - App Background (shared)
struct AppBackgroundView: View {
    var body: some View {
        SerenelyTheme.backgroundGradient
            .ignoresSafeArea()
    }
}

private struct AppBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            AppBackgroundView()
            content
        }
    }
}

extension View {
    func appBackground() -> some View { modifier(AppBackgroundModifier()) }
}
