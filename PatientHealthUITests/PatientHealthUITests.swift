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

    func testDeletePatientRemovesProfile() {
        let app = openPatientForm()
        let firstName = app.textFields["First name"]
        firstName.tap()
        firstName.typeText("Delete")
        let lastName = app.textFields["Last name"]
        lastName.tap()
        lastName.typeText("Me")
        let medicalID = app.textFields["Medical ID"]
        medicalID.tap()
        medicalID.typeText("DELETE-UI-001")
        app.buttons["birthDateButton"].tap()
        let useDate = app.buttons["Use date"]
        if !useDate.waitForExistence(timeout: 2) {
            app.buttons["birthDateButton"].tap()
        }
        useDate.tap()
        let consent = app.switches["Consent to local profile storage"]
        for _ in 0..<8 {
            if consent.isHittable { break }
            app.swipeUp()
        }
        consent.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        let save = app.buttons["Save"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let row = app.staticTexts["Delete Me"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        app.buttons["Delete patient"].tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(row.waitForExistence(timeout: 3))
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
