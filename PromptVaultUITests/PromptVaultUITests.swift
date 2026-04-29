import XCTest

final class PromptVaultUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testScreenshots() {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += ["-FASTLANE_SNAPSHOT", "YES", "-ui_testing"]
        app.launch()
        sleep(2)

        snapshot("01-Library")

        let addButton = app.navigationBars.buttons.element(boundBy: app.navigationBars.buttons.count - 1)
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
            sleep(1)
            snapshot("02-Editor")
            let cancel = app.buttons["Cancel"]
            if cancel.exists { cancel.tap(); sleep(1) }
        }

        let settingsButton = app.navigationBars.buttons.element(boundBy: 0)
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snapshot("03-Settings")
            let done = app.buttons["Done"]
            if done.exists { done.tap(); sleep(1) }
        }

        if settingsButton.exists {
            settingsButton.tap()
            sleep(1)
            let unlock = app.buttons["Unlock Premium"]
            if unlock.exists {
                unlock.tap()
                sleep(1)
                snapshot("04-Paywall")
            }
        }
    }
}
