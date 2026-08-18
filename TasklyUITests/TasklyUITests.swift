//
//  TasklyUITests.swift
//  TasklyUITests
//
//  Created by Ryan Gupta on 7/28/26.
//

import XCTest

final class TasklyUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Smoke test for the core loop: add quests, clear one, and visit every screen.
    @MainActor
    func testCoreLoop() throws {
        let app = XCUIApplication()
        app.launch()

        capture(app, name: "01-today-empty")

        addStarterQuests(app)
        allowNotificationsIfPrompted()

        XCTAssertTrue(
            app.staticTexts["Make the bed"].waitForExistence(timeout: 5),
            "Starter quests should land on the board"
        )

        addCustomQuest(app, titled: "Ship a feature")
        XCTAssertTrue(
            app.staticTexts["Ship a feature"].waitForExistence(timeout: 5),
            "A hand written quest should land on the board"
        )
        capture(app, name: "03-today-populated")

        // Clearing a quest should award XP and move it into the cleared section.
        let complete = app.buttons["Complete Make the bed"]
        XCTAssertTrue(complete.waitForExistence(timeout: 3), "Quest rows expose a complete button")
        complete.tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["CLEARED"].exists, "Cleared section should appear")
        capture(app, name: "04-today-completed")

        // Quest detail. Use a quest that is still pending, since cleared ones
        // move to the bottom section and may be scrolled out of reach.
        app.staticTexts["Brush teeth"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["TRACK RECORD"].waitForExistence(timeout: 4), "Detail screen should open")
        capture(app, name: "05-quest-detail")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["Focus"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["Start focusing"].waitForExistence(timeout: 4)
            || app.staticTexts["coin to spend"].exists
            || app.staticTexts["coins to spend"].exists,
            "Focus tab should open a timer and coin wallet")
        capture(app, name: "06-focus")

        app.buttons["Stats"].tap()
        sleep(1)
        capture(app, name: "07-stats")

        app.buttons["Profile"].tap()
        sleep(1)
        capture(app, name: "08-profile")

        // Scroll to the notification settings and the queued alert preview.
        let profileScroll = app.scrollViews.firstMatch
        profileScroll.swipeUp()
        profileScroll.swipeUp()
        sleep(1)
        XCTAssertTrue(app.staticTexts["NOTIFICATIONS"].exists, "Notification settings should be reachable")
        capture(app, name: "10-notifications")

        profileScroll.swipeUp()
        profileScroll.swipeUp()
        sleep(1)
        XCTAssertTrue(app.staticTexts["NEXT ALERTS"].exists, "The queued alert preview should be reachable")
        capture(app, name: "11-next-alerts")
    }

    /// Queueing a quest for tomorrow should keep it off today's board.
    @MainActor
    func testPlanningTomorrow() throws {
        let app = XCUIApplication()
        app.launch()

        let planTomorrow = app.buttons["Plan Tomorrow"]
        XCTAssertTrue(planTomorrow.waitForExistence(timeout: 5), "Today screen should offer a tomorrow switcher")
        planTomorrow.tap()
        sleep(1)
        capture(app, name: "12-tomorrow-board")

        // Either the empty state button or the footer button, depending on what is queued.
        let addForTomorrow = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'for tomorrow'"))
            .firstMatch
        XCTAssertTrue(addForTomorrow.waitForExistence(timeout: 4), "Tomorrow should offer a way to queue a quest")
        addForTomorrow.tap()

        XCTAssertTrue(app.navigationBars["New quest"].waitForExistence(timeout: 4), "Editor should open")

        // The editor should already be pointed at tomorrow. Look before typing, since the
        // keyboard covers the schedule controls.
        XCTAssertTrue(app.staticTexts["STARTS"].exists, "Start day picker should be present")
        let editorScroll = app.scrollViews.firstMatch
        editorScroll.swipeUp()
        sleep(1)
        capture(app, name: "13-editor-tomorrow")
        editorScroll.swipeDown()
        sleep(1)

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Editor should expose a title field")
        field.tap()
        field.typeText("Write a draft")
        app.navigationBars["New quest"].buttons["Save"].tap()

        XCTAssertTrue(
            app.staticTexts["Write a draft"].waitForExistence(timeout: 5),
            "A quest queued for tomorrow should show on tomorrow's board"
        )
        capture(app, name: "14-tomorrow-queued")

        app.buttons["Plan Today"].tap()
        sleep(1)
        XCTAssertFalse(
            app.staticTexts["Write a draft"].exists,
            "A quest queued for tomorrow should stay off today's board"
        )
        capture(app, name: "15-today-unchanged")
    }

    // MARK: - Flows

    private func addStarterQuests(_ app: XCUIApplication) {
        let browse = app.buttons["Browse starter quests"]
        guard browse.waitForExistence(timeout: 5) else { return }
        browse.tap()

        // Take whichever rows are on screen; the gallery scrolls and exact
        // positions are not what this test is verifying.
        var selected = 0
        for title in ["Make the bed", "Brush teeth", "Drink water", "Tidy the desk"] {
            let row = app.buttons.containing(.staticText, identifier: title).firstMatch
            if row.exists, row.isHittable {
                row.tap()
                selected += 1
            }
        }
        XCTAssertGreaterThanOrEqual(selected, 2, "Several starter quests should be selectable")
        capture(app, name: "02-starter-gallery")

        let add = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add '")).firstMatch
        if add.waitForExistence(timeout: 3) { add.tap() }
    }

    private func addCustomQuest(_ app: XCUIApplication, titled title: String) {
        app.buttons["New quest"].tap()
        XCTAssertTrue(app.navigationBars["New quest"].waitForExistence(timeout: 4), "Editor should open")

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Editor should expose a title field")
        field.tap()
        field.typeText(title)

        capture(app, name: "09-editor")
        app.navigationBars["New quest"].buttons["Save"].tap()
    }

    // MARK: - Helpers

    /// The permission prompt is owned by springboard, so it needs its own query.
    private func allowNotificationsIfPrompted() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
