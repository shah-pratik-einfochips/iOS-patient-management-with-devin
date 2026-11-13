import Foundation

struct Patient: Codable, Identifiable, Equatable {
    var id = UUID()
    var firstName = ""
    var lastName = ""
    var medicalID = ""
    var birthDate: Date?
    static let examinationTypes = ["Routine checkup", "Emergency", "Follow-up", "Consultation", "Diagnostic", "Preventive"]
    var gender = "unknown"
    var ethnicity = ""
    var phone = ""
    var email = ""
    var bloodType = "Unknown"
    var allergies = ""
    var medications = ""
    var conditions = ""
    var examinationPurpose = ""
    var examinationType = ""
    var performedBy = ""
    var referredBy = ""
    var consentGranted = false
    var vitals: [VitalReading] = []

    var name: String { "\(firstName) \(lastName)".trimmingCharacters(in: .whitespacesAndNewlines) }

    func validationErrors(now: Date = Date()) -> [String] {
        var errors: [String] = []
        if firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("First name is required.") }
        if lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Last name is required.") }
        if medicalID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Medical ID is required.") }
        if let birthDate {
            if birthDate > now { errors.append("Date of birth cannot be in the future.") }
        } else {
            errors.append("Select a date of birth.")
        }
        if !examinationType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !Self.examinationTypes.contains(examinationType) {
            errors.append("Select a listed examination type.")
        }
        if !email.isEmpty && email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            errors.append("Enter a valid email address.")
        }
        if !consentGranted { errors.append("Consent is required to store this profile in this prototype.") }
        return errors
    }
}

enum VitalMetric: String, CaseIterable, Identifiable, Codable {
    case systolic, diastolic, heartRate, height, weight, temperature, respiratoryRate, oxygenSaturation, pain

    var id: String { rawValue }
    var title: String {
        switch self {
        case .systolic: "Systolic blood pressure"
        case .diastolic: "Diastolic blood pressure"
        case .heartRate: "Heart rate"
        case .height: "Height"
        case .weight: "Weight"
        case .temperature: "Temperature"
        case .respiratoryRate: "Respiratory rate"
        case .oxygenSaturation: "SpO2"
        case .pain: "Pain level"
        }
    }
    var unit: String {
        switch self {
        case .systolic, .diastolic: "mmHg"
        case .heartRate: "bpm"
        case .height: "cm"
        case .weight: "kg"
        case .temperature: "°C"
        case .respiratoryRate: "breaths/min"
        case .oxygenSaturation: "%"
        case .pain: "/10"
        }
    }
    var inputRange: ClosedRange<Double> {
        switch self {
        case .systolic: 20...350
        case .diastolic: 10...250
        case .heartRate: 10...350
        case .height: 20...300
        case .weight: 0.1...700
        case .temperature: 25...45
        case .respiratoryRate: 1...100
        case .oxygenSaturation: 1...100
        case .pain: 0...10
        }
    }
    var referenceRange: ClosedRange<Double>? {
        switch self {
        case .systolic: 90...119
        case .diastolic: 60...79
        case .heartRate: 60...100
        case .temperature: 36.1...37.2
        case .respiratoryRate: 12...20
        case .oxygenSaturation: 95...100
        case .pain: 0...3
        case .height, .weight: nil
        }
    }
    func isOutsideReference(_ value: Double) -> Bool {
        referenceRange.map { !$0.contains(value) } ?? false
    }
}

struct VitalReading: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var values: [VitalMetric: Double] = [:]
    var symptoms = ""

    static func nearest(in readings: [VitalReading], to date: Date, metric: VitalMetric) -> VitalReading? {
        readings.filter { $0.values[metric] != nil }.min {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        }
    }

    var meanArterialPressure: Double? {
        guard let systolic = values[.systolic], let diastolic = values[.diastolic] else { return nil }
        return (systolic + 2 * diastolic) / 3
    }

    func validationErrors(now: Date = Date(), birthDate: Date? = nil) -> [String] {
        var errors: [String] = []
        if date > now { errors.append("Reading date cannot be in the future.") }
        if let birthDate, date < birthDate { errors.append("Reading date cannot precede date of birth.") }
        if values.isEmpty { errors.append("Enter at least one vital sign.") }
        for metric in VitalMetric.allCases {
            if let value = values[metric], !value.isFinite || !metric.inputRange.contains(value) {
                errors.append("\(metric.title) must be within \(metric.inputRange.lowerBound.formatted())–\(metric.inputRange.upperBound.formatted()) \(metric.unit).")
            }
        }
        if (values[.systolic] == nil) != (values[.diastolic] == nil) {
            errors.append("Enter both systolic and diastolic blood pressure.")
        }
        if let systolic = values[.systolic], let diastolic = values[.diastolic], systolic <= diastolic {
            errors.append("Systolic pressure must exceed diastolic pressure.")
        }
        return errors
    }
}

enum DecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> Double? {
        let separator = locale.decimalSeparator ?? "."
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: separator, with: ".")
        guard normalized.range(of: #"^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)$"#, options: .regularExpression) != nil,
              let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}

enum UnitConversion {
    static func kilograms(pounds: Double) -> Double { pounds * 0.45359237 }
    static func centimeters(feet: Double, inches: Double) -> Double { (feet * 12 + inches) * 2.54 }
    static func celsius(fahrenheit: Double) -> Double { (fahrenheit - 32) * 5 / 9 }
}
