import XCTest

final class NavigationTests: XCTestCase {
    func testDrawerKeyboardAndVoice() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let menu = app.buttons["chat.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        for _ in 0..<3 {
            menu.tap()
            let title = app.staticTexts["sidebar.title"]
            XCTAssertTrue(title.waitForExistence(timeout: 3))
            XCTAssertGreaterThanOrEqual(title.frame.minX, 0)
            XCTAssertLessThan(title.frame.maxX, app.frame.width)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
            XCTAssertTrue(menu.isHittable)
        }
        // Reproduce an interrupted partial edge drag and leaving/returning to the app.
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.45)))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)

        let input = app.textFields["chat.input"]
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        input.typeText("Bonjour")
        XCTAssertEqual(input.value as? String, "Bonjour")
        // Keyboard's accessibility frame omits QuickType on iOS 27.
        // Measure against UIKit's actual top edge (also visible in the screenshot).
        let keyboardEdge = app.otherElements["keyboard.edge"]
        XCTAssertTrue(keyboardEdge.exists)
        let gap = keyboardEdge.frame.maxY - app.buttons["chat.sendOrVoice"].frame.maxY
        let keyboardShot = XCTAttachment(screenshot: app.screenshot())
        keyboardShot.name = "keyboard-alignment"
        keyboardShot.lifetime = .keepAlways
        add(keyboardShot)
        print("COMPOSER_KEYBOARD_GAP=\(gap)")
        XCTAssertGreaterThanOrEqual(gap, 0)
        XCTAssertLessThanOrEqual(gap, 12, "Composer must stay next to the keyboard")
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 7))
        app.buttons["chat.sendOrVoice"].tap()
        XCTAssertTrue(app.staticTexts["voice.title"].waitForExistence(timeout: 5))
        // Audio permission may be refused on a simulator: navigation must remain usable.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            if springboard.alerts.firstMatch.waitForExistence(timeout: 2) {
                springboard.alerts.firstMatch.buttons.firstMatch.tap()
            }
        }
        let close = app.buttons["voice.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertTrue(menu.isHittable)
        app.buttons["chat.attach"].tap()
        XCTAssertTrue(app.buttons["Ajouter une image"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Prendre une photo"].exists)
        XCTAssertTrue(app.buttons["Ajouter un fichier"].exists)
        XCTAssertFalse(app.buttons["Tous les outils"].exists)
    }
}
