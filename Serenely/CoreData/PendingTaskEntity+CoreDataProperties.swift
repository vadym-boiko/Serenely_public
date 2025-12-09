//
//  PendingTaskEntity+CoreDataProperties.swift
//  Serenely
//
//  Created by Vadym on 13.08.2025.
//
//

import Foundation
import CoreData


extension PendingTaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PendingTaskEntity> {
        return NSFetchRequest<PendingTaskEntity>(entityName: "PendingTaskEntity")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var details: String?
    @NSManaged public var id: UUID?
    @NSManaged public var statusRaw: String?
    @NSManaged public var title: String?
    @NSManaged public var usefulnessRaw: String?

}

extension PendingTaskEntity : Identifiable {

}
