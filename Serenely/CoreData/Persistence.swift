import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Serenely")
        if inMemory {
            let d = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions.first?.url = d
        }
        container.loadPersistentStores { _, error in
            if let error = error { fatalError("Core Data load error: \(error)") }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        let ctx = container.viewContext
        guard ctx.hasChanges else { return }
        do { try ctx.save() } catch { print("CoreData save error:", error) }
    }
}
