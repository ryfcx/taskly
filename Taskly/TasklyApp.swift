//
//  TasklyApp.swift
//  Taskly
//
//  Created by Ryan Gupta on 7/28/26.
//

import SwiftUI
import SwiftData

@main
struct TasklyApp: App {
    @State private var session = SessionState()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskItem.self,
            CompletionRecord.self,
            PlayerProfile.self,
            FocusSession.self,
            Reward.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(sharedModelContainer)
    }
}
