import SwiftUI

struct SummarySheetView: View {
    @Binding var editedSummary: String
    @State var thumbsUp: Bool? = nil
    @State var flags: Set<String> = []

    @Binding var suggestedTasks: [ActionTask]
    let onConfirm: (_ editedSummary: String, _ thumbsUp: Bool?, _ flags: [String], _ feedbackTasks: [ActionTask], _ saved: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var workingTasks: [ActionTask] = []

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ScrollView { contentSection }
                actionButtons
            }
            .background(Color.black.ignoresSafeArea())
            .foregroundStyle(.white)
            .onAppear(perform: prepareWorkingTasks)
            .onChange(of: suggestedTasks.count) { _, _ in
                prepareWorkingTasks()
            }
            .navigationTitle(L10n.t("summary.results", "Results"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Components
extension SummarySheetView {
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("summary.title", "Session summary"))
                .font(SerenelyTheme.Font.title)
            summaryEditor
            feedbackButtons
            tagsIfNeeded
            Divider().padding(.vertical, 4)
            tasksSuggestionSection
        }
        .padding()
    }

    private var summaryEditor: some View {
        Group {
            if editedSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(SerenelyTheme.accent)
                    Text(L10n.t("summary.generating", "Generating summary…"))
                        .foregroundStyle(SerenelyTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .padding(10)
                .background(SerenelyTheme.bubble)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                TextEditor(text: $editedSummary)
                    .frame(minHeight: 140)
                    .padding(10)
                    .background(SerenelyTheme.bubble)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: 12) {
            feedbackButton(symbol: "👍", value: true)
            feedbackButton(symbol: "👎", value: false)
            Spacer()
        }
    }

    private func feedbackButton(symbol: String, value: Bool) -> some View {
        Button { thumbsUp = value } label: {
            Text(symbol)
                .padding(8)
                .background(buttonBG(value))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var tagsIfNeeded: some View {
        Group {
            if thumbsUp == false {
                TagRow(
                    all: ["too_long","inaccurate","too_dry","preachy"],
                    selected: $flags,
                    labels: [L10n.t("flags.too_long", "Too long"), L10n.t("flags.inaccurate", "Inaccurate"), L10n.t("flags.too_dry", "Too dry"), L10n.t("flags.preachy", "Preachy")]
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeOut(duration: 0.2), value: thumbsUp)
    }

    @ViewBuilder
    private var tasksSuggestionSection: some View {
        Group {
            if suggestedTasks.isEmpty && workingTasks.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(SerenelyTheme.accent)
                    Text(L10n.t("summary.preparing_tasks", "Preparing task suggestions…"))
                        .foregroundStyle(SerenelyTheme.textSecondary)
                }
            } else if workingTasks.isEmpty {
                Text(L10n.t("summary.no_tasks", "No task suggestions this time — and that's ok."))
                    .font(SerenelyTheme.Font.body)
                    .foregroundStyle(SerenelyTheme.textSecondary)
            } else {
                Text(L10n.t("summary.tasks_title", "Task suggestions (optional)"))
                    .font(SerenelyTheme.Font.title)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach($workingTasks) { $task in
                        TaskCardView(task: $task, mode: .summarySheet)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onConfirm(editedSummary, thumbsUp, Array(flags), [], false)
                dismiss()
            } label: {
                Text(L10n.t("summary.skip", "Skip"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }

            Button {
                onConfirm(editedSummary, thumbsUp, Array(flags), workingTasks, true)
                dismiss()
            } label: {
                Text(L10n.t("summary.save", "Save to portrait"))
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(SerenelyTheme.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(14)
            }
        }
        .padding([.horizontal, .bottom])
    }

    private func buttonBG(_ isUp: Bool) -> Color {
        (thumbsUp == isUp) ? Color.white.opacity(0.2) : Color.white.opacity(0.08)
    }

    private func prepareWorkingTasks() {
        workingTasks = suggestedTasks.map { t in
            var nt = t; nt.status = .skipped; nt.usefulness = .notSet; return nt
        }
    }

    // MARK: - Local Component
    struct TagRow: View {
        let all: [String]
        @Binding var selected: Set<String>
        let labels: [String]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("summary.what_wrong", "What was wrong?"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 8) {
                    ForEach(Array(all.enumerated()), id: \.offset) { i, key in
                        let isOn = selected.contains(key)
                        Text(labels[i])
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isOn ? Color.white.opacity(0.2) : Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .onTapGesture { if isOn { selected.remove(key) } else { selected.insert(key) } }
                    }
                }
            }
        }
    }
}
