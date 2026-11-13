import XCTest

final class PatientHealthUITests: XCTestCase {
    private func openPatientForm() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let add = app.buttons["Add patient"]
        XCTAssertTrue(add.waitForExistence(timeout: 15))
        add.tap()
        XCTAssertTrue(app.buttons["birthDateButton"].waitForExistence(timeout: 5))
        return app
    }

    func testBirthDateRequiresExplicitConfirmation() {
        let app = openPatientForm()
        let birthDate = app.buttons["birthDateButton"]
        XCTAssertTrue(birthDate.label.contains("Select date"))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        birthDate.tap()
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(birthDate.label.contains("Select date"))
        birthDate.tap()
        app.buttons["Use date"].tap()
        XCTAssertFalse(birthDate.label.contains("Select date"))
        app.buttons["Cancel"].tap()
    }

    func testExaminationMenuContainsExpectedOptions() {
        let app = openPatientForm()
        let picker = app.buttons["examinationTypePicker"]
        for _ in 0..<8 {
            if picker.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(picker.isHittable)
        picker.tap()
        for option in ["Routine checkup", "Emergency", "Follow-up", "Consultation", "Diagnostic", "Preventive"] {
            XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 3), option)
        }
        app.buttons["Emergency"].tap()
        XCTAssertTrue(picker.label.contains("Emergency"))
        app.buttons["Cancel"].tap()
    }
}
