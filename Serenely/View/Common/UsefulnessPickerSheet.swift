// filepath: /Users/vadym/Desktop/Developing/Serenely/Serenely/View/Common/UsefulnessPickerSheet.swift
import SwiftUI

struct UsefulnessPickerSheet: View {
    @Binding var task: ActionTask
    var onSave: () -> Void = {}
    var onCancel: () -> Void = {}

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .frame(width: 44, height: 5)
                .opacity(0.25)
                .padding(.top, 8)

            Text(L10n.t("rating.title", "Rate usefulness"))
                .font(SerenelyTheme.Font.title)
                .foregroundStyle(SerenelyTheme.textPrimary)

            Text(task.title)
                .font(SerenelyTheme.Font.caption)
                .foregroundStyle(SerenelyTheme.textSecondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                SerenelyTheme.CapsuleChip(title: L10n.t("rating.low", "low"), active: task.usefulness == .low) { task.usefulness = .low }
                SerenelyTheme.CapsuleChip(title: L10n.t("rating.medium", "medium"), active: task.usefulness == .medium) { task.usefulness = .medium }
                SerenelyTheme.CapsuleChip(title: L10n.t("rating.high", "high"), active: task.usefulness == .high) { task.usefulness = .high }
            }
            .padding(.top, 6)

            Spacer(minLength: 8)

            HStack {
                Button(L10n.t("common.back", "Back")) { onCancel() }
                    .buttonStyle(.plain)
                Spacer()
                Button(L10n.t("task.action.done", "Done")) { onSave() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .presentationDetents([.height(240), .medium])
        .preferredColorScheme(.dark)
    }
}
