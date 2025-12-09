// filepath: /Users/vadym/Desktop/Developing/Serenely/Serenely/View/Tasks/ActiveTaskListView.swift
import SwiftUI
import CoreData
import UIKit

struct ActiveTaskListView: View {
    @Environment(\.managedObjectContext) private var ctx

    // NOTE: Чтобы избежать крэшей при отсутствии createdAt в схеме,
    // используем fetch без сортировки и сортируем в памяти безопасно.
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    )
    private var tasks: FetchedResults<TaskEntity>

    // Безопасная сортировка: по createdAt DESC, если есть; иначе по title ASC
    private var sortedTasks: [TaskEntity] {
        tasks.sorted { lhs, rhs in
            let lCreated = lhs.value(forKey: "createdAt") as? Date
            let rCreated = rhs.value(forKey: "createdAt") as? Date
            switch (lCreated, rCreated) {
            case let (l?, r?):
                if l == r { return (lhs.title) < (rhs.title) }
                return l > r
            case (_?, nil):
                return true // у левой есть createdAt, у правой нет — левая выше
            case (nil, _?):
                return false
            default:
                // Оба без createdAt — сортируем по заголовку ASC, локализовано
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    var body: some View {
        Group {
            if sortedTasks.isEmpty {
                VStack(spacing: 12) {
                    Text("Немає активних задач")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Додай нову задачу, і вона з’явиться тут.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedTasks) { task in
                        Row(task: task,
                            onComplete: { delete(task) },
                            onSkip: { delete(task) }
                        )
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Завершити") { delete(task) }
                                .tint(.green)
                                .accessibilityLabel("Завершити задачу")
                            Button("Пропустити", role: .destructive) { delete(task) }
                                .tint(.orange)
                                .accessibilityLabel("Пропустити задачу")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Задачі")
    }

    private func delete(_ task: TaskEntity) {
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            ctx.delete(task)
            try? ctx.save()
        }
    }
}

// MARK: - Inline Row
private extension ActiveTaskListView {
    struct Row: View {
        let task: TaskEntity
        let onComplete: () -> Void
        let onSkip: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let details = task.details, !details.isEmpty {
                    Text(details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    Button("Завершити", action: onComplete)
                        .font(.callout)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    Button("Пропустити", action: onSkip)
                        .font(.callout)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .padding(.top, 2)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }
}

// If your model DOES include createdAt and you prefer Core Data sort:
// Replace @FetchRequest sortDescriptors with:
// sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
// If not, you can use title ASC:
// sortDescriptors: [NSSortDescriptor(key: "title", ascending: true)]
