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
                QuestTemplate(title: "Make the bed", symbol: "bed.double.fill", category: .routine, difficulty: .trivial, reminderMinutes: 7 * 60 + 30),
                QuestTemplate(title: "Brush teeth", symbol: "sparkles", category: .routine, difficulty: .trivial, reminderMinutes: 7 * 60 + 45),
                QuestTemplate(title: "Drink water", symbol: "drop.fill", category: .routine, difficulty: .trivial),
                QuestTemplate(title: "Tidy the desk", symbol: "tray.fill", category: .chores, difficulty: .easy),
                QuestTemplate(title: "Lights out on time", symbol: "moon.stars.fill", category: .routine, difficulty: .easy, reminderMinutes: 22 * 60 + 30)
            ]
        ),
        QuestPack(
            name: "Study",
            blurb: "Classes, reading and practice",
            symbol: "book.fill",
            category: .study,
            templates: [
                QuestTemplate(title: "Study session", symbol: "book.fill", category: .study, difficulty: .normal, reminderMinutes: 17 * 60),
                QuestTemplate(title: "Practice problems", symbol: "puzzlepiece.fill", category: .study, difficulty: .hard, reminderMinutes: 18 * 60),
                QuestTemplate(title: "Exam day", symbol: "trophy.fill", category: .study, difficulty: .ultra),
                QuestTemplate(title: "All-nighter push", symbol: "sparkles", category: .study, difficulty: .mythic),
                QuestTemplate(title: "Review notes", symbol: "text.book.closed.fill", category: .study, difficulty: .easy),
                QuestTemplate(title: "Read for 20 minutes", symbol: "book.closed.fill", category: .mind, difficulty: .easy)
            ]
        ),
        QuestPack(
            name: "Build",
            blurb: "Projects and creative work",
            symbol: "hammer.fill",
            category: .build,
            templates: [
                QuestTemplate(title: "Work on a project", symbol: "hammer.fill", category: .build, difficulty: .hard, reminderMinutes: 19 * 60),
                QuestTemplate(title: "Ship a feature", symbol: "flag.fill", category: .build, difficulty: .hard),
                QuestTemplate(title: "Deep work day", symbol: "flame.fill", category: .build, difficulty: .ultra),
                QuestTemplate(title: "Write something down", symbol: "pencil.line", category: .build, difficulty: .normal),
                QuestTemplate(title: "Fix one bug", symbol: "ant.fill", category: .build, difficulty: .normal),
                QuestTemplate(title: "Plan tomorrow", symbol: "list.bullet.clipboard.fill", category: .build, difficulty: .easy, reminderMinutes: 21 * 60)
            ]
        ),
        QuestPack(
            name: "Stay Human",
            blurb: "People, movement and headspace",
            symbol: "bubble.left.and.bubble.right.fill",
            category: .social,
            templates: [
                QuestTemplate(title: "Message someone", symbol: "message.fill", category: .social, difficulty: .easy),
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
