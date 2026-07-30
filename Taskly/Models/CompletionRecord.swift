//
//  CompletionRecord.swift
//  Taskly
//

import Foundation
import SwiftData

/// One logged clear of a quest. Kept as its own record so stats and history
/// survive edits to the parent quest.
@Model
final class CompletionRecord {
    var id: UUID = UUID()
    /// Exact moment the quest was cleared.
    var timestamp: Date = Date()
    /// Start of the day the clear counts toward.
    var day: Date = Calendar.current.startOfDay(for: Date())
    var xpAwarded: Int = 0
    /// Stored so undoing a clear takes back exactly what it paid, even if rates change.
    var coinsAwarded: Int = 0
    /// Snapshot of the category so history stays accurate if the quest is later re-categorised.
    var categoryRaw: String = TaskCategory.other.rawValue

    var task: TaskItem?

    init(timestamp: Date = Date(), xpAwarded: Int, category: TaskCategory, task: TaskItem? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.day = Calendar.current.startOfDay(for: timestamp)
        self.xpAwarded = xpAwarded
        self.categoryRaw = category.rawValue
        self.task = task
    }

    var category: TaskCategory {
        TaskCategory(rawValue: categoryRaw) ?? .other
    }
}
