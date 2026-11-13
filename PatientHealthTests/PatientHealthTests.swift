import CryptoKit
import SwiftData
import XCTest
@testable import PatientHealth

final class PatientHealthTests: XCTestCase {
    private func patient() -> Patient {
        Patient(firstName: "Test", lastName: "Patient", medicalID: "SYNTHETIC-001", birthDate: Date(timeIntervalSince1970: 0), consentGranted: true)
    }

    func testNewPatientRequiresExplicitBirthDate() {
        let value = Patient(firstName: "Test", lastName: "Patient", medicalID: "TEST", consentGranted: true)
        XCTAssertNil(value.birthDate)
        XCTAssertFalse(value.validationErrors().isEmpty)
    }

    func testExaminationTypeMustBeListed() {
        var value = patient()
        value.examinationType = "Unlisted examination"
        XCTAssertFalse(value.validationErrors().isEmpty)
        for type in ["Routine checkup", "Emergency", "Follow-up", "Consultation", "Diagnostic", "Preventive", ""] {
            value.examinationType = type
            XCTAssertTrue(value.validationErrors().isEmpty, type)
        }
    }

    func testExistingPatientPayloadRetainsBirthDate() throws {
        let value = patient()
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(Patient.self, from: data)
        XCTAssertEqual(decoded.birthDate, value.birthDate)
        XCTAssertTrue(decoded.validationErrors().isEmpty)
    }

    func testPayloadWithoutBirthDateRequiresSelection() throws {
        let data = try JSONEncoder().encode(patient())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "birthDate")
        let decoded = try JSONDecoder().decode(Patient.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.birthDate)
        XCTAssertFalse(decoded.validationErrors().isEmpty)
    }

    func testChartSelectsNearestMeasuredReading() {
        let first = VitalReading(date: Date(timeIntervalSince1970: 100), values: [.heartRate: 70])
        let missing = VitalReading(date: Date(timeIntervalSince1970: 190), values: [.pain: 1])
        let last = VitalReading(date: Date(timeIntervalSince1970: 200), values: [.heartRate: 80])
        XCTAssertEqual(VitalReading.nearest(in: [first, missing, last], to: Date(timeIntervalSince1970: 190), metric: .heartRate)?.id, last.id)
        XCTAssertEqual(VitalReading.nearest(in: [first, last], to: .distantPast, metric: .heartRate)?.id, first.id)
        XCTAssertNil(VitalReading.nearest(in: [missing], to: missing.date, metric: .heartRate))
        XCTAssertNil(VitalReading.nearest(in: [], to: Date(), metric: .heartRate))
    }

    func testValidPatient() {
        XCTAssertTrue(patient().validationErrors().isEmpty)
    }

    func testRequiredFields() {
        XCTAssertEqual(Patient().validationErrors().count, 5)
    }

    func testWhitespaceNamesAndIDAreRejected() {
        var value = patient()
        value.firstName = " \n"
        value.lastName = " "
        value.medicalID = "\t"
        XCTAssertEqual(value.validationErrors().count, 3)
    }

    func testFutureBirthDate() {
        var value = patient()
        value.birthDate = .distantFuture
        XCTAssertFalse(value.validationErrors().isEmpty)
    }

    func testInvalidEmail() {
        var value = patient()
        value.email = "invalid@"
        XCTAssertFalse(value.validationErrors().isEmpty)
        value.email = "test@example.com"
        XCTAssertTrue(value.validationErrors().isEmpty)
    }

    func testConsentRequired() {
        var value = patient()
        value.consentGranted = false
        XCTAssertFalse(value.validationErrors().isEmpty)
    }

    func testDecimalInputRejectsPartialAndNonfiniteValues() {
        for text in ["70abc", "NaN", "inf", "1,000", "1 2", "", "1.2.3", "1e3"] {
            XCTAssertNil(DecimalInput.parse(text, locale: Locale(identifier: "en_US")), text)
        }
        XCTAssertEqual(DecimalInput.parse(" 70.5 ", locale: Locale(identifier: "en_US")), 70.5)
        XCTAssertEqual(DecimalInput.parse("37,5", locale: Locale(identifier: "fr_FR")), 37.5)
    }

    func testUnitConversions() {
        XCTAssertEqual(UnitConversion.kilograms(pounds: 100), 45.359237, accuracy: 0.000001)
        XCTAssertEqual(UnitConversion.centimeters(feet: 5, inches: 10), 177.8, accuracy: 0.000001)
        XCTAssertEqual(UnitConversion.celsius(fahrenheit: 98.6), 37, accuracy: 0.000001)
        XCTAssertEqual(UnitConversion.celsius(fahrenheit: 32), 0, accuracy: 0.000001)
    }

    func testMeanArterialPressure() {
        let value = VitalReading(values: [.systolic: 120, .diastolic: 80])
        XCTAssertEqual(value.meanArterialPressure ?? 0, 93.333333, accuracy: 0.00001)
        XCTAssertNil(VitalReading(values: [.systolic: 120]).meanArterialPressure)
    }

    func testEmptyReadingRejected() {
        XCTAssertFalse(VitalReading().validationErrors().isEmpty)
    }

    func testPartialBloodPressureRejected() {
        XCTAssertFalse(VitalReading(values: [.systolic: 120]).validationErrors().isEmpty)
        XCTAssertFalse(VitalReading(values: [.diastolic: 80]).validationErrors().isEmpty)
    }

    func testInvertedBloodPressureRejected() {
        XCTAssertFalse(VitalReading(values: [.systolic: 80, .diastolic: 120]).validationErrors().isEmpty)
    }

    func testInvalidVitalsRejected() {
        for metric in VitalMetric.allCases {
            for value in [-Double.infinity, Double.infinity, Double.nan, metric.inputRange.lowerBound - 1, metric.inputRange.upperBound + 1] {
                XCTAssertFalse(VitalReading(values: [metric: value]).validationErrors().isEmpty, "\(metric): \(value)")
            }
        }
    }

    func testValidReading() {
        XCTAssertTrue(VitalReading(values: [.systolic: 120, .diastolic: 80, .heartRate: 70, .pain: 0]).validationErrors().isEmpty)
    }

    func testFutureReadingRejected() {
        XCTAssertFalse(VitalReading(date: .distantFuture, values: [.heartRate: 70]).validationErrors().isEmpty)
    }

    func testReadingBeforeBirthRejected() {
        let value = VitalReading(date: Date(timeIntervalSince1970: 0), values: [.heartRate: 70])
        XCTAssertFalse(value.validationErrors(birthDate: Date()).isEmpty)
    }

    func testReferenceRanges() {
        XCTAssertFalse(VitalMetric.heartRate.isOutsideReference(70))
        XCTAssertTrue(VitalMetric.heartRate.isOutsideReference(130))
        XCTAssertFalse(VitalMetric.height.isOutsideReference(180))
    }

    func testKeychainKeyPersists() throws {
        let first = try PatientEncryption.loadKey()
        let second = try PatientEncryption.loadKey()
        XCTAssertEqual(first.withUnsafeBytes { Data($0) }, second.withUnsafeBytes { Data($0) })
    }

    @MainActor func testPersistentStorageOpens() throws {
        let container = try ModelContainer(for: EncryptedPatientRecord.self)
        _ = try PatientStore(container: container, key: PatientEncryption.loadKey())
    }

    func testEncryptionRoundTrip() throws {
        var value = patient()
        value.vitals = [VitalReading(values: [.heartRate: 72])]
        let key = SymmetricKey(size: .bits256)
        let payload = try PatientEncryption.seal(value, key: key)
        XCTAssertEqual(try PatientEncryption.open(payload, id: value.id, key: key), value)
        XCTAssertNil(String(data: payload, encoding: .utf8)?.range(of: value.medicalID))
    }

    func testWrongKeyRejected() throws {
        let value = patient()
        let payload = try PatientEncryption.seal(value, key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try PatientEncryption.open(payload, id: value.id, key: SymmetricKey(size: .bits256)))
    }

    func testTamperedPayloadRejected() throws {
        let value = patient()
        let key = SymmetricKey(size: .bits256)
        var payload = try PatientEncryption.seal(value, key: key)
        payload[payload.count / 2] ^= 1
        XCTAssertThrowsError(try PatientEncryption.open(payload, id: value.id, key: key))
    }

    func testRecordSubstitutionRejected() throws {
        let value = patient()
        let key = SymmetricKey(size: .bits256)
        let payload = try PatientEncryption.seal(value, key: key)
        XCTAssertThrowsError(try PatientEncryption.open(payload, id: UUID(), key: key))
    }

    @MainActor func testStoreSavesAndReloads() throws {
        let container = try ModelContainer(for: EncryptedPatientRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let key = SymmetricKey(size: .bits256)
        let store = try PatientStore(container: container, key: key)
        let value = patient()
        try store.save(value)
        try store.addReading(VitalReading(values: [.heartRate: 70]), to: value.id)
        let reloaded = try PatientStore(container: container, key: key)
        XCTAssertEqual(reloaded.patients.count, 1)
        XCTAssertEqual(reloaded.patients.first?.vitals.first?.values[.heartRate], 70)
        var updated = reloaded.patients[0]
        updated.firstName = "Updated"
        try reloaded.save(updated)
        XCTAssertEqual(reloaded.patients.count, 1)
        XCTAssertEqual(try PatientStore(container: container, key: key).patients.first?.firstName, "Updated")
    }

    @MainActor func testDuplicateMedicalIDRejected() throws {
        let container = try ModelContainer(for: EncryptedPatientRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try PatientStore(container: container, key: SymmetricKey(size: .bits256))
        try store.save(patient())
        var duplicate = patient()
        duplicate.medicalID = " synthetic-001 "
        XCTAssertThrowsError(try store.save(duplicate))
        XCTAssertEqual(store.patients.count, 1)
    }

    @MainActor func testStoreRejectsInvalidData() throws {
        let container = try ModelContainer(for: EncryptedPatientRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = try PatientStore(container: container, key: SymmetricKey(size: .bits256))
        XCTAssertThrowsError(try store.save(Patient()))
        let value = patient()
        try store.save(value)
        XCTAssertThrowsError(try store.addReading(VitalReading(values: [.pain: 11]), to: value.id))
        XCTAssertTrue(store.patients[0].vitals.isEmpty)
    }
}
