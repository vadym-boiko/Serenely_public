import SwiftUI
import UIKit

struct TasksView: View {
    @EnvironmentObject var locale: LocalizationManager
    @StateObject var vm = TasksViewModel()
    @State private var ratingTaskID: UUID? = nil
    @State private var lastStatuses: [UUID: TaskStatus] = [:]
    @State private var completedTasks: [ActionTask] = []
    @State private var showHistory: Bool = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            AppBackgroundView()
            mainContent
        }
        .navigationTitle(L10n.t("tasks.title", "Tasks"))
        .onAppear {
            lastStatuses = Dictionary(uniqueKeysWithValues: vm.tasks.map { ($0.id, $0.status) })
        }
        .onChange(of: vm.tasks) { _, newValue in
            for t in newValue {
                let prev = lastStatuses[t.id]
                if t.status == .done, prev != .done, t.usefulness == .notSet {
                    ratingTaskID = t.id
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    break
                }
            }
            lastStatuses = Dictionary(uniqueKeysWithValues: newValue.map { ($0.id, $0.status) })
        }
        .sheet(item: Binding(
            get: { ratingTaskID.map { IdentBox($0) } },
            set: { ratingTaskID = $0?.value }
        )) { box in
            if let b = binding(for: box.value) {
                UsefulnessPickerSheet(
                    task: b,
                    onSave: {
                        // Після збереження оцінки переносимо завдання в історію
                        if let idx = vm.tasks.firstIndex(where: { $0.id == b.wrappedValue.id }) {
                            moveToHistory(task: b.wrappedValue, status: .done, at: idx)
                        }
                        ratingTaskID = nil
                    },
                    onCancel: {
                        // Назад: відкотити статус і оцінку, залишити завдання в активному списку
                        if let idx = vm.tasks.firstIndex(where: { $0.id == b.wrappedValue.id }) {
                            vm.tasks[idx].status = .pending
                            vm.tasks[idx].usefulness = .notSet
                            vm.persist()
                        }
                        ratingTaskID = nil
                    }
                )
                .presentationBackground(.ultraThinMaterial)
            }
        }
    }
    
    private var mainContent: some View {
        Group {
            ScrollView {
                LazyVStack(spacing: 16) {
                    activeTasksSection
                    emptyStateSection
                    swipeHintSection
                    historySection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .simultaneousGesture(swipeGesture)
        }
    }
    
    private var activeTasksSection: some View {
        ForEach(vm.tasks, id: \.id) { task in
            SwipeableTaskRow(
                onDone: { 
                    if let idx = vm.tasks.firstIndex(where: { $0.id == task.id }) {
                        // Позначаємо як виконане, але ще не переносимо в історію —
                        // дочекаємось оцінки корисності
                        vm.tasks[idx].status = .done
                        vm.persist()
                    }
                },
                onSkip: { 
                    if let idx = vm.tasks.firstIndex(where: { $0.id == task.id }) {
                        moveToHistory(task: task, status: .skipped, at: idx)
                    }
                },
                onDelete: { 
                    if let idx = vm.tasks.firstIndex(where: { $0.id == task.id }) {
                        vm.delete(at: IndexSet(integer: idx))
                    }
                }
            ) {
                TaskCardView(task: Binding(
                    get: { task },
                    set: { newTask in
                        if let idx = vm.tasks.firstIndex(where: { $0.id == task.id }) {
                            vm.tasks[idx] = newTask
                        }
                    }
                ), mode: .full)
            }
        }
    }
    
    private var emptyStateSection: some View {
        Group {
            if vm.tasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 44))
                        .padding(.bottom, 6)
                    Text(L10n.t("tasks.empty_title", "No tasks"))
                        .font(.headline)
                    Text(L10n.t("tasks.empty_subtitle", "The assistant can suggest ideas at the end of the session — but it's optional."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    private var swipeHintSection: some View {
        Group {
            if !completedTasks.isEmpty && !showHistory {
                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                    Text(L10n.t("tasks.history.swipe_up", "Swipe up for history"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .opacity(0.6)
                }
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.3), value: showHistory)
            }
        }
    }
    
    private var historySection: some View {
        Group {
            if showHistory && !completedTasks.isEmpty {
                VStack(spacing: 12) {
                    // Close history hint
                    VStack(spacing: 8) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .opacity(0.6)
                        Text(L10n.t("tasks.history.swipe_down", "Swipe down to close"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(0.6)
                    }
                    .padding(.vertical, 8)
                    
                    SectionHeader(title: L10n.t("tasks.history.title", "Task history"), subtitle: L10n.t("tasks.history.subtitle", "Completed and skipped"))
                }
                .padding(.top, vm.tasks.isEmpty ? 0 : 20)
                
                ForEach(completedTasks, id: \.id) { task in
                    if task.status == .skipped {
                        HistoryTaskRow(
                            onRestore: { restoreTask(task: task) },
                            onDelete: { deleteFromHistory(task: task) }
                        ) {
                            TaskCardView(task: Binding(
                                get: { task },
                                set: { _ in }
                            ), mode: .full)
                            .opacity(0.7)
                        }
                    } else {
                        // Completed tasks - only delete
                        DeleteOnlyTaskRow(
                            onDelete: { deleteFromHistory(task: task) }
                        ) {
                            TaskCardView(task: Binding(
                                get: { task },
                                set: { _ in }
                            ), mode: .full)
                            .opacity(0.7)
                        }
                    }
                }
            }
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only respond to vertical swipes, ignore horizontal ones
                let verticalMovement = abs(value.translation.height)
                let horizontalMovement = abs(value.translation.width)
                
                // Only process if vertical movement is greater than horizontal
                if verticalMovement > horizontalMovement {
                    // Only respond to upward swipes when history is hidden
                    if !showHistory && value.translation.height < 0 {
                        dragOffset = value.translation.height
                    }
                    // Only respond to downward swipes when history is shown
                    else if showHistory && value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
            }
            .onEnded { value in
                let verticalMovement = abs(value.translation.height)
                let horizontalMovement = abs(value.translation.width)
                
                // Only process if vertical movement is greater than horizontal
                guard verticalMovement > horizontalMovement else { return }
                
                let velocity = value.predictedEndTranslation.height - value.translation.height
                
                if !showHistory {
                    // Show history if swiped up enough or with sufficient velocity
                    if dragOffset < -5 || velocity < -20 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showHistory = true
                        }
                    }
                } else {
                    // Hide history if swiped down enough or with sufficient velocity
                    if dragOffset > 5 || velocity > 20 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showHistory = false
                        }
                    }
                }
                
                dragOffset = 0
            }
    }
}

// MARK: - SwipeableTaskRow Component
struct SwipeableTaskRow<Content: View>: View {
    let onDone: () -> Void
    let onSkip: () -> Void
    let onDelete: () -> Void
    let content: () -> Content
    
    @State private var offsetX: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showHint: Bool = false
    @State private var autoResetWorkItem: DispatchWorkItem? = nil
    
    private let leftActionWidth: CGFloat = 200
    private let rightActionWidth: CGFloat = 120
    private let snapThreshold: CGFloat = 60
    private let autoActionVelocity: CGFloat = 450
    private let autoActionDistanceFactor: CGFloat = 0.8
    private let hintDelay: Double = 2.0
    private let autoResetDelay: Double = 1.0
    
    var body: some View {
        ZStack {
            // Background actions with improved visuals
            HStack(spacing: 0) {
                // Left actions (Done + Skip)
                HStack(spacing: 0) {
                    actionButton(
                        title: L10n.t("task.action.done", "Done"),
                        icon: "checkmark.circle.fill",
                        colors: [SerenelyTheme.accent.opacity(0.9), SerenelyTheme.accent.opacity(0.7)],
                        action: handleDone,
                        isActive: offsetX > snapThreshold,
                        progress: doneProgress
                    )
                    
                    actionButton(
                        title: L10n.t("task.action.skip", "Skip"),
                        icon: "arrow.uturn.right.circle.fill",
                        colors: [SerenelyTheme.bubble.opacity(0.9), SerenelyTheme.bubble.opacity(0.7)],
                        action: handleSkip,
                        isActive: offsetX > snapThreshold
                    )
                }
                .frame(width: leftActionWidth)
                .opacity(leftActionOpacity)
                .scaleEffect(leftActionScale)
                .padding(.leading, 16)
                
                Spacer(minLength: 0)
                
                // Right action (Delete)
                actionButton(
                    title: L10n.t("task.action.delete", "Delete"),
                    icon: "trash.fill",
                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                    action: handleDelete,
                    isActive: offsetX < -snapThreshold,
                    progress: deleteProgress
                )
                .frame(width: rightActionWidth)
                .opacity(rightActionOpacity)
                .scaleEffect(rightActionScale)
            }
            
            // Foreground content with enhanced interactions
            content()
                .background(Color.clear)
                .offset(x: offsetX)
                .scaleEffect(contentScale)
                .rotationEffect(.degrees(contentRotation))
                // Коли відкриті дії — передаємо тачі на кнопки дій, а не на контент
                .allowsHitTesting(abs(offsetX) < snapThreshold)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            cancelAutoReset()
                            // Обробляємо ТІЛЬКИ горизонтальні жести, вертикальні пропускаємо для скролу
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = true
                            dragOffset = value.translation.width
                            let newOffset = dragOffset
                            if newOffset > 0 {
                                offsetX = min(newOffset, leftActionWidth)
                            } else {
                                offsetX = max(newOffset, -rightActionWidth)
                            }
                        }
                        .onEnded { value in
                            // Only handle if it was primarily horizontal
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = false
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            // Strong swipe auto-actions
                            if offsetX > leftActionWidth * autoActionDistanceFactor || velocity > autoActionVelocity {
                                handleDone()
                                return
                            }
                            if offsetX < -rightActionWidth * autoActionDistanceFactor || velocity < -autoActionVelocity {
                                handleDelete()
                                return
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if offsetX > snapThreshold || velocity > 150 {
                                    offsetX = leftActionWidth
                                } else if offsetX < -snapThreshold || velocity < -150 {
                                    offsetX = -rightActionWidth
                                } else {
                                    offsetX = 0
                                }
                            }
                            dragOffset = 0

                            // Schedule auto reset if row is left or right opened and no action selected
                            if offsetX == leftActionWidth || offsetX == -rightActionWidth {
                                scheduleAutoReset()
                            }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        cancelAutoReset()
                        offsetX = 0
                    }
                }
                .onLongPressGesture(minimumDuration: 0.1) {
                    // Long press feedback
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
        }
        .clipped()
        .onAppear {
            // Show hint after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + hintDelay) {
                if offsetX == 0 {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showHint = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showHint = false
                        }
                    }
                }
            }
        }
        .onDisappear {
            cancelAutoReset()
        }
    }
    
    private var leftActionOpacity: Double {
        max(0, min(1, Double(offsetX / leftActionWidth)))
    }
    
    private var rightActionOpacity: Double {
        max(0, min(1, Double(-offsetX / rightActionWidth)))
    }
    
    private var leftActionScale: CGFloat {
        let progress = offsetX / leftActionWidth
        return 1.0 + (0.1 * progress)
    }
    
    private var rightActionScale: CGFloat {
        let progress = -offsetX / rightActionWidth
        return 1.0 + (0.1 * progress)
    }
    
    private var contentScale: CGFloat {
        let maxOffset = max(leftActionWidth, rightActionWidth)
        let progress = abs(offsetX) / maxOffset
        return 1.0 - (0.02 * progress)
    }
    
    private var contentRotation: Double {
        let maxOffset = max(leftActionWidth, rightActionWidth)
        let progress = offsetX / maxOffset
        return Double(progress * 2) // Subtle rotation
    }
    
    private var doneProgress: CGFloat {
        let denom = leftActionWidth * autoActionDistanceFactor
        guard denom > 0 else { return 0 }
        return max(0, min(1, offsetX / denom))
    }
    
    private var deleteProgress: CGFloat {
        let denom = rightActionWidth * autoActionDistanceFactor
        guard denom > 0 else { return 0 }
        return max(0, min(1, -offsetX / denom))
    }
    
    private func handleDone() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cancelAutoReset()
            offsetX = 0
        }
        onDone()
    }
    
    private func handleSkip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cancelAutoReset()
            offsetX = 0
        }
        onSkip()
    }
    
    private func handleDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            cancelAutoReset()
            offsetX = 0
        }
        onDelete()
    }

    private func scheduleAutoReset() {
        cancelAutoReset()
        let work = DispatchWorkItem {
            if !isDragging && (offsetX == leftActionWidth || offsetX == -rightActionWidth) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    offsetX = 0
                }
            }
        }
        autoResetWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + autoResetDelay, execute: work)
    }

    private func cancelAutoReset() {
        autoResetWorkItem?.cancel()
        autoResetWorkItem = nil
    }
    
    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void,
        isActive: Bool = false,
        progress: CGFloat? = nil
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(SerenelyTheme.textPrimary)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                    if let p = progress {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        Circle()
                            .trim(from: 0, to: max(0, min(1, p)))
                            .stroke(SerenelyTheme.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 30, height: 30)
                    }
                }
                
                Text(title)
                    .font(SerenelyTheme.Font.caption)
                    .foregroundColor(SerenelyTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(isActive ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .shadow(
                        color: colors.first?.opacity(isActive ? 0.4 : 0.2) ?? .clear,
                        radius: isActive ? 10 : 6,
                        x: 0,
                        y: isActive ? 6 : 3
                    )
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - HistoryTaskRow Component
struct HistoryTaskRow<Content: View>: View {
    let onRestore: () -> Void
    let onDelete: () -> Void
    let content: () -> Content
    
    @State private var offsetX: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    private let leftActionWidth: CGFloat = 120
    private let rightActionWidth: CGFloat = 120
    private let snapThreshold: CGFloat = 60
    private let autoActionVelocity: CGFloat = 450
    private let autoActionDistanceFactor: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                // Left action (Restore)
                actionButton(
                    title: L10n.t("task.action.restore", "Restore"),
                    icon: "arrow.uturn.left.circle.fill",
                    colors: [SerenelyTheme.accent.opacity(0.9), SerenelyTheme.accent.opacity(0.7)],
                    action: handleRestore,
                    isActive: offsetX > snapThreshold,
                    progress: restoreProgress
                )
                .frame(width: leftActionWidth)
                .opacity(leftActionOpacity)
                .scaleEffect(leftActionScale)
                .padding(.leading, 16)
                
                Spacer(minLength: 0)
                
                // Right action (Delete)
                actionButton(
                    title: L10n.t("task.action.delete", "Delete"),
                    icon: "trash.fill",
                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                    action: handleDelete,
                    isActive: offsetX < -snapThreshold,
                    progress: historyDeleteProgress
                )
                .frame(width: rightActionWidth)
                .opacity(rightActionOpacity)
                .scaleEffect(rightActionScale)
            }
            
            // Foreground content
            content()
                .background(Color.clear)
                .offset(x: offsetX)
                .scaleEffect(contentScale)
                // Давати можливість натискати кнопку видалення, коли вона видима
                .allowsHitTesting(abs(offsetX) < snapThreshold)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = true
                            dragOffset = value.translation.width
                            let newOffset = dragOffset
                            if newOffset > 0 {
                                offsetX = min(newOffset, leftActionWidth)
                            } else {
                                offsetX = max(newOffset, -rightActionWidth)
                            }
                        }
                        .onEnded { value in
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = false
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            // Strong swipe auto-actions
                            if offsetX > leftActionWidth * autoActionDistanceFactor || velocity > autoActionVelocity {
                                handleRestore()
                                return
                            }
                            if offsetX < -rightActionWidth * autoActionDistanceFactor || velocity < -autoActionVelocity {
                                handleDelete()
                                return
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if offsetX > snapThreshold || velocity > 150 {
                                    offsetX = leftActionWidth
                                } else if offsetX < -snapThreshold || velocity < -150 {
                                    offsetX = -rightActionWidth
                                } else {
                                    offsetX = 0
                                }
                            }
                            dragOffset = 0
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offsetX = 0
                    }
                }
        }
        .clipped()
    }
    
    private var leftActionOpacity: Double {
        max(0, min(1, Double(offsetX / leftActionWidth)))
    }
    
    private var rightActionOpacity: Double {
        max(0, min(1, Double(-offsetX / rightActionWidth)))
    }
    
    private var leftActionScale: CGFloat {
        let progress = offsetX / leftActionWidth
        return 1.0 + (0.1 * progress)
    }
    
    private var rightActionScale: CGFloat {
        let progress = -offsetX / rightActionWidth
        return 1.0 + (0.1 * progress)
    }
    
    private var contentScale: CGFloat {
        let maxOffset = max(leftActionWidth, rightActionWidth)
        let progress = abs(offsetX) / maxOffset
        return 1.0 - (0.02 * progress)
    }
    
    private var restoreProgress: CGFloat {
        let denom = leftActionWidth * autoActionDistanceFactor
        guard denom > 0 else { return 0 }
        return max(0, min(1, offsetX / denom))
    }
    
    private var historyDeleteProgress: CGFloat {
        let denom = rightActionWidth * autoActionDistanceFactor
        guard denom > 0 else { return 0 }
        return max(0, min(1, -offsetX / denom))
    }
    
    private func handleRestore() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsetX = 0
        }
        onRestore()
    }
    
    private func handleDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsetX = 0
        }
        onDelete()
    }
    
    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void,
        isActive: Bool = false,
        progress: CGFloat? = nil
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(SerenelyTheme.textPrimary)
                        .scaleEffect(isActive ? 1.2 : 1.0)
                    if let p = progress {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                            .frame(width: 30, height: 30)
                        Circle()
                            .trim(from: 0, to: max(0, min(1, p)))
                            .stroke(SerenelyTheme.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 30, height: 30)
                    }
                }
                
                Text(title)
                    .font(SerenelyTheme.Font.caption)
                    .foregroundColor(SerenelyTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(isActive ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .shadow(
                        color: colors.first?.opacity(isActive ? 0.4 : 0.2) ?? .clear,
                        radius: isActive ? 10 : 6,
                        x: 0,
                        y: isActive ? 6 : 3
                    )
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(isActive ? L10n.t("access.action.ready", "Ready to execute") : L10n.t("access.swipe_to_activate", "Swipe to activate"))
    }
}

// MARK: - DeleteOnlyTaskRow Component
struct DeleteOnlyTaskRow<Content: View>: View {
    let onDelete: () -> Void
    let content: () -> Content
    
    @State private var offsetX: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    private let rightActionWidth: CGFloat = 120
    private let snapThreshold: CGFloat = 60
    private let autoActionVelocity: CGFloat = 450
    private let autoActionDistanceFactor: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                
                // Right action (Delete only)
                actionButton(
                    title: "Видалити",
                    icon: "trash.fill",
                    colors: [Color.red.opacity(0.8), Color.red.opacity(0.6)],
                    action: handleDelete,
                    isActive: offsetX < -snapThreshold
                )
                .frame(width: rightActionWidth)
                .opacity(rightActionOpacity)
                .scaleEffect(rightActionScale)
            }
            
            // Foreground content
            content()
                .background(Color.clear)
                .offset(x: offsetX)
                .scaleEffect(contentScale)
                // Давати можливість натискати кнопку видалення, коли вона видима
                .allowsHitTesting(abs(offsetX) < snapThreshold)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = true
                            dragOffset = value.translation.width
                            let newOffset = dragOffset
                            if newOffset < 0 {
                                offsetX = max(newOffset, -rightActionWidth)
                            }
                        }
                        .onEnded { value in
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            guard absX > absY else { return }

                            isDragging = false
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            // Strong swipe auto-delete
                            if offsetX < -rightActionWidth * autoActionDistanceFactor || velocity < -autoActionVelocity {
                                handleDelete()
                                return
                            }
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if offsetX < -snapThreshold || velocity < -150 {
                                    offsetX = -rightActionWidth
                                } else {
                                    offsetX = 0
                                }
                            }
                            dragOffset = 0
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        offsetX = 0
                    }
                }
        }
        .clipped()
    }
    
    private var rightActionOpacity: Double {
        max(0, min(1, Double(-offsetX / rightActionWidth)))
    }
    
    private var rightActionScale: CGFloat {
        let progress = -offsetX / rightActionWidth
        return 1.0 + (0.1 * progress)
    }
    
    private var contentScale: CGFloat {
        let progress = abs(offsetX) / rightActionWidth
        return 1.0 - (0.02 * progress)
    }
    
    private func handleDelete() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offsetX = 0
        }
        onDelete()
    }
    
    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        colors: [Color],
        action: @escaping () -> Void,
        isActive: Bool = false
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(SerenelyTheme.textPrimary)
                    .scaleEffect(isActive ? 1.2 : 1.0)
                
                Text(title)
                    .font(SerenelyTheme.Font.caption)
                    .foregroundColor(SerenelyTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(isActive ? 1.0 : 0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.clear, lineWidth: 0)
                    )
                    .shadow(
                        color: colors.first?.opacity(isActive ? 0.4 : 0.2) ?? .clear,
                        radius: isActive ? 10 : 6,
                        x: 0,
                        y: isActive ? 6 : 3
                    )
            )
            .scaleEffect(isActive ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(isActive ? L10n.t("access.action.ready", "Ready to execute") : L10n.t("access.swipe_to_activate", "Swipe to activate"))
    }
}

// MARK: - Components & Helpers
extension TasksView {
    private func moveToHistory(task: ActionTask, status: TaskStatus, at index: Int) {
        var updatedTask = task
        updatedTask.status = status
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove from active tasks
            vm.delete(at: IndexSet(integer: index))
            
            // Add to history
            completedTasks.insert(updatedTask, at: 0)
        }
        
        // Show rating if completed
        if status == .done && task.usefulness == .notSet {
            ratingTaskID = task.id
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
    
    private func restoreTask(task: ActionTask) {
        var restoredTask = task
        restoredTask.status = .pending
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            // Remove from history
            if let idx = completedTasks.firstIndex(where: { $0.id == task.id }) {
                completedTasks.remove(at: idx)
            }
            
            // Add back to active tasks
            vm.tasks.append(restoredTask)
            
            // Hide history if no more completed tasks
            if completedTasks.isEmpty {
                showHistory = false
            }
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func deleteFromHistory(task: ActionTask) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if let idx = completedTasks.firstIndex(where: { $0.id == task.id }) {
                completedTasks.remove(at: idx)
            }
            
            // Hide history if no more completed tasks
            if completedTasks.isEmpty {
                showHistory = false
            }
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    private func binding(for id: UUID) -> Binding<ActionTask>? {
        // First check active tasks
        if let idx = vm.tasks.firstIndex(where: { $0.id == id }) {
        return Binding(
            get: { vm.tasks[idx] },
            set: { vm.tasks[idx] = $0 }
        )
        }
        
        // Then check completed tasks
        if let idx = completedTasks.firstIndex(where: { $0.id == id }) {
            return Binding(
                get: { completedTasks[idx] },
                set: { completedTasks[idx] = $0 }
            )
        }
        
        return nil
    }

    private struct IdentBox<T: Hashable>: Identifiable {
        let value: T
        var id: T { value }
        init(_ v: T) { self.value = v }
    }

    struct SegButton: View {
        let title: String
        let isOn: Bool
        let action: () -> Void
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.footnote)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(isOn ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
