import Foundation
import CoreData

protocol PortraitStoring {
    func loadPortrait() -> UserPortrait
    func savePortrait(_ p: UserPortrait)
    func clearPortrait()

    func loadPendingTasks() -> [ActionTask]
    func savePendingTasks(_ tasks: [ActionTask])
    func clearPendingTasks()
}

final class CoreDataStore: PortraitStoring {
    static let shared = CoreDataStore()
    private let ctx: NSManagedObjectContext

    private init(ctx: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.ctx = ctx
    }

    // MARK: - Portrait
    func loadPortrait() -> UserPortrait {
        let req = NSFetchRequest<NSManagedObject>(entityName: "UserPortraitEntity")
        req.fetchLimit = 1
        if let obj = (try? ctx.fetch(req))?.first {
            return portrait(from: obj) ?? .empty
        } else {
            return .empty
        }
    }

    func savePortrait(_ p: UserPortrait) {
        let req = NSFetchRequest<NSManagedObject>(entityName: "UserPortraitEntity")
        req.fetchLimit = 1
        let obj = ((try? ctx.fetch(req))?.first)
        ?? NSEntityDescription.insertNewObject(forEntityName: "UserPortraitEntity", into: ctx)

        obj.setValue(p.summary, forKey: "summary")
        obj.setValue(p.lastUpdated, forKey: "lastUpdated")

        obj.setValue(Int64(p.taskStats.totalSuggested), forKey: "tasksTotalSuggested")
        obj.setValue(Int64(p.taskStats.completed),      forKey: "tasksCompleted")
        obj.setValue(Int64(p.taskStats.skipped),        forKey: "tasksSkipped")
        obj.setValue(Int64(p.taskStats.usefulnessHigh), forKey: "usefulnessHigh")
        obj.setValue(Int64(p.taskStats.usefulnessMedium), forKey: "usefulnessMedium")
        obj.setValue(Int64(p.taskStats.usefulnessLow),  forKey: "usefulnessLow")

        obj.setValue(try? JSONEncoder().encode(p.focusAreas),        forKey: "focusAreasData")
        obj.setValue(try? JSONEncoder().encode(p.helpfulStrategies), forKey: "helpfulStrategiesData")
        obj.setValue(try? JSONEncoder().encode(p.preferenceWeights), forKey: "preferenceWeightsData")

        PersistenceController.shared.save()
    }

    func clearPortrait() {
        let req = NSFetchRequest<NSFetchRequestResult>(entityName: "UserPortraitEntity")
        let del = NSBatchDeleteRequest(fetchRequest: req)
        _ = try? ctx.execute(del)
        PersistenceController.shared.save()
    }

    private func portrait(from obj: NSManagedObject) -> UserPortrait? {
        let summary      = obj.value(forKey: "summary") as? String ?? ""
        let lastUpdated  = obj.value(forKey: "lastUpdated") as? Date ?? .now

        let total   = Int((obj.value(forKey: "tasksTotalSuggested") as? Int64) ?? 0)
        let done    = Int((obj.value(forKey: "tasksCompleted") as? Int64) ?? 0)
        let skipped = Int((obj.value(forKey: "tasksSkipped") as? Int64) ?? 0)
        let uH      = Int((obj.value(forKey: "usefulnessHigh") as? Int64) ?? 0)
        let uM      = Int((obj.value(forKey: "usefulnessMedium") as? Int64) ?? 0)
        let uL      = Int((obj.value(forKey: "usefulnessLow") as? Int64) ?? 0)

        let focus: [String] = {
            guard let data = obj.value(forKey: "focusAreasData") as? Data, !data.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }()

        let strategies: [String] = {
            guard let data = obj.value(forKey: "helpfulStrategiesData") as? Data, !data.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }()

        let weights: [String: Double] = {
            guard let data = obj.value(forKey: "preferenceWeightsData") as? Data, !data.isEmpty else { return [:] }
            return (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
        }()

        return UserPortrait(
            summary: summary.isEmpty ? UserPortrait.empty.summary : summary,
            focusAreas: focus,
            helpfulStrategies: strategies,
            lastUpdated: lastUpdated,
            taskStats: TaskStats(
                totalSuggested: total,
                completed: done,
                skipped: skipped,
                usefulnessHigh: uH,
                usefulnessMedium: uM,
                usefulnessLow: uL
            ),
            preferenceWeights: weights
        )
    }

    // MARK: - Pending Tasks
    func loadPendingTasks() -> [ActionTask] {
        let req = NSFetchRequest<NSManagedObject>(entityName: "PendingTaskEntity")
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        guard let objs = try? ctx.fetch(req) else { return [] }
        return objs.compactMap { task(from: $0) }
    }

    func savePendingTasks(_ tasks: [ActionTask]) {
        clearPendingTasks()
        for t in tasks {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "PendingTaskEntity", into: ctx)
            obj.setValue(t.id, forKey: "id")
            obj.setValue(t.title, forKey: "title")
            obj.setValue(t.details, forKey: "details")
            obj.setValue(t.createdAt, forKey: "createdAt")
            obj.setValue(t.status.rawValue, forKey: "statusRaw")
            obj.setValue(t.usefulness.rawValue, forKey: "usefulnessRaw")
        }
        PersistenceController.shared.save()
    }

    func clearPendingTasks() {
        let req = NSFetchRequest<NSFetchRequestResult>(entityName: "PendingTaskEntity")
        let del = NSBatchDeleteRequest(fetchRequest: req)
        _ = try? ctx.execute(del)
        PersistenceController.shared.save()
    }

    private func task(from obj: NSManagedObject) -> ActionTask? {
        guard
            let id = obj.value(forKey: "id") as? UUID,
            let title = obj.value(forKey: "title") as? String,
            let created = obj.value(forKey: "createdAt") as? Date,
            let statusRaw = obj.value(forKey: "statusRaw") as? String,
            let usefulnessRaw = obj.value(forKey: "usefulnessRaw") as? String
        else { return nil }

        return ActionTask(
            id: id,
            title: title,
            details: obj.value(forKey: "details") as? String,
            createdAt: created,
            status: TaskStatus(rawValue: statusRaw) ?? .pending,
            usefulness: TaskUsefulness(rawValue: usefulnessRaw) ?? .notSet
        )
    }
}
