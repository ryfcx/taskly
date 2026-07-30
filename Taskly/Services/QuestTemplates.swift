//
//  QuestTemplates.swift
//  Taskly
//

import Foundation

/// A ready made quest the player can add with one tap.
struct QuestTemplate: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var symbol: String
    var category: TaskCategory
    var difficulty: TaskDifficulty
    var recurrence: RecurrenceKind = .daily
    var weekdayMask: Int = Weekdays.all
    var reminderMinutes: Int?

    func makeTask(sortIndex: Int, startDay: Date? = nil) -> TaskItem {
        TaskItem(
            title: title,
            category: category,
            difficulty: difficulty,
            recurrence: recurrence,
            weekdayMask: weekdayMask,
            reminderEnabled: reminderMinutes != nil,
            reminderMinutes: reminderMinutes ?? 8 * 60,
            iconName: symbol,
            startDay: startDay,
            sortIndex: sortIndex
        )
    }
}

struct QuestPack: Identifiable {
    var id: String { name }
    var name: String
    var blurb: String
    var symbol: String
    var category: TaskCategory
    var templates: [QuestTemplate]
}

enum QuestTemplates {
    static let packs: [QuestPack] = [
        QuestPack(
            name: "Morning & Night",
            blurb: "The small stuff that runs your day",
            symbol: "sunrise.fill",
            category: .routine,
            templates: [
                QuestTemplate(title: "Make my bed", symbol: "bed.double.fill", category: .routine, difficulty: .trivial, reminderMinutes: 7 * 60 + 30),
                QuestTemplate(title: "Brush my teeth", symbol: "sparkles", category: .routine, difficulty: .trivial, reminderMinutes: 7 * 60 + 45),
                QuestTemplate(title: "Drink water", symbol: "drop.fill", category: .routine, difficulty: .trivial),
                QuestTemplate(title: "Tidy my desk", symbol: "tray.fill", category: .chores, difficulty: .easy),
                QuestTemplate(title: "Lights out by 11", symbol: "moon.stars.fill", category: .routine, difficulty: .easy, reminderMinutes: 22 * 60 + 30)
            ]
        ),
        QuestPack(
            name: "Study Grind",
            blurb: "Math, USACO and everything in between",
            symbol: "book.fill",
            category: .study,
            templates: [
                QuestTemplate(title: "Study math", symbol: "function", category: .study, difficulty: .normal, reminderMinutes: 17 * 60),
                QuestTemplate(title: "Study USACO", symbol: "chart.xyaxis.line", category: .study, difficulty: .hard, reminderMinutes: 18 * 60),
                QuestTemplate(title: "Solve a practice problem", symbol: "puzzlepiece.fill", category: .study, difficulty: .normal),
                QuestTemplate(title: "Review notes", symbol: "text.book.closed.fill", category: .study, difficulty: .easy),
                QuestTemplate(title: "Read 20 pages", symbol: "book.closed.fill", category: .mind, difficulty: .easy)
            ]
        ),
        QuestPack(
            name: "Builder Mode",
            blurb: "Ship the apps you keep thinking about",
            symbol: "hammer.fill",
            category: .build,
            templates: [
                QuestTemplate(title: "Work on my app", symbol: "app.badge.fill", category: .build, difficulty: .hard, reminderMinutes: 19 * 60),
                QuestTemplate(title: "Work on second app", symbol: "square.stack.3d.up.fill", category: .build, difficulty: .hard),
                QuestTemplate(title: "Commit something today", symbol: "curlybraces", category: .build, difficulty: .normal),
                QuestTemplate(title: "Fix one bug", symbol: "ant.fill", category: .build, difficulty: .normal),
                QuestTemplate(title: "Plan tomorrow's build", symbol: "list.bullet.clipboard.fill", category: .build, difficulty: .easy, reminderMinutes: 21 * 60)
            ]
        ),
        QuestPack(
            name: "Stay Human",
            blurb: "People, movement and headspace",
            symbol: "bubble.left.and.bubble.right.fill",
            category: .social,
            templates: [
                QuestTemplate(title: "Text a friend", symbol: "message.fill", category: .social, difficulty: .easy),
                QuestTemplate(title: "Call family", symbol: "phone.fill", category: .social, difficulty: .easy, recurrence: .weekly, weekdayMask: 0b0000001),
                QuestTemplate(title: "Workout", symbol: "dumbbell.fill", category: .fitness, difficulty: .hard, recurrence: .weekly, weekdayMask: Weekdays.weekdaysOnly),
                QuestTemplate(title: "Go for a walk", symbol: "figure.walk", category: .fitness, difficulty: .easy),
                QuestTemplate(title: "Journal for 5 minutes", symbol: "pencil.line", category: .mind, difficulty: .easy, reminderMinutes: 21 * 60 + 30)
            ]
        )
    ]

    /// A short, opinionated starter board offered on first launch.
    static var starterBoard: [QuestTemplate] {
        [
            packs[0].templates[0],
            packs[0].templates[1],
            packs[1].templates[0],
            packs[1].templates[1],
            packs[2].templates[0],
            packs[3].templates[0]
        ]
    }

    /// Every template, de-duplicated, for the search list in the editor.
    static var all: [QuestTemplate] {
        packs.flatMap(\.templates)
    }
}
