// filepath: /Users/vadym/Desktop/Developing/Serenely/Serenely/Models/TaskStatus.swift
import Foundation

public enum TaskStatus: String, CaseIterable, Identifiable, Codable {
    case pending
    case inProgress
    case completed
    case skipped

    public var id: String { rawValue }

    public var isActive: Bool {
        switch self {
        case .pending, .inProgress: return true
        default: return false
        }
    }

    public var isArchived: Bool {
        switch self {
        case .completed, .skipped: return true
        default: return false
        }
    }

    public var displayTitle: String {
        switch self {
        case .pending:    return "Активна"
        case .inProgress: return "В роботі"
        case .completed:  return "Завершена"
        case .skipped:    return "Пропущена"
        }
    }
}
