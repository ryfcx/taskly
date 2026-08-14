//
//  BoardOrder.swift
//  Taskly
//

import Foundation

/// Rewrites `sortIndex` so a day's pending quests match the order the player just dragged them into.
/// Tasks that aren't in that pending set keep their relative places around them.
enum BoardOrder {
    static func apply(pendingOrder: [UUID], to tasks: [TaskItem]) {
        guard !pendingOrder.isEmpty else { return }

        let byID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let pendingSet = Set(pendingOrder)
        var pendingQueue = pendingOrder.compactMap { byID[$0] }
        guard pendingQueue.count == pendingOrder.count else { return }

        var result: [TaskItem] = []
        result.reserveCapacity(tasks.count)

        for task in tasks.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            if pendingSet.contains(task.id) {
                guard let next = pendingQueue.first else { continue }
                result.append(next)
                pendingQueue.removeFirst()
            } else {
                result.append(task)
            }
        }

        // Any pending IDs that somehow weren't visited still go on the end.
        result.append(contentsOf: pendingQueue)

        for (index, task) in result.enumerated() {
            if task.sortIndex != index {
                task.sortIndex = index
            }
        }
    }

    /// Moves `fromID` onto `ontoID` within `pendingOrder`, returning the new UUID order.
    static func moving(_ fromID: UUID, onto ontoID: UUID, in pendingOrder: [UUID]) -> [UUID]? {
        guard fromID != ontoID,
              let from = pendingOrder.firstIndex(of: fromID),
              let to = pendingOrder.firstIndex(of: ontoID)
        else { return nil }

        var next = pendingOrder
        let item = next.remove(at: from)
        next.insert(item, at: to)
        return next
    }
}
