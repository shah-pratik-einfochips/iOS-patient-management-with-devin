import UIKit

enum PatientExport {
    static func csv(_ patient: Patient) -> String {
        var lines = ["name,medical_id,date_of_birth,gender,examination_type",
                     [patient.name, patient.medicalID, patient.birthDate?.formatted(date: .numeric, time: .omitted) ?? "", patient.gender, patient.examinationType]
                        .map(quote).joined(separator: ","),
                     "",
                     "reading_date,metric,value,unit,outside_illustrative_range,map,symptoms"]
        for reading in patient.vitals.sorted(by: { $0.date < $1.date }) {
            let measured = VitalMetric.allCases.filter { reading.values[$0] != nil }
            let rows = measured.isEmpty ? [nil] : measured.map { Optional($0) }
            for (index, metric) in rows.enumerated() {
                let value = metric.flatMap { reading.values[$0] }
                lines.append([
                    reading.date.formatted(date: .numeric, time: .shortened),
                    metric?.title ?? "",
                    value.map(format) ?? "",
                    metric?.unit ?? "",
                    metric.flatMap { m in value.map { m.isOutsideReference($0) ? "yes" : "" } } ?? "",
                    index == 0 ? reading.meanArterialPressure.map(format) ?? "" : "",
                    index == 0 ? quote(reading.symptoms) : "",
                ].joined(separator: ","))
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func quote(_ text: String) -> String {
        "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func csvURL(_ patient: Patient) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("patient-\(patient.medicalID.isEmpty ? patient.id.uuidString : patient.medicalID).csv")
        try csv(patient).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func pdfURL(_ patient: Patient) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 48
        let lineHeight: CGFloat = 18
        let title: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
        let section: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14)]
        let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            var y = margin
            func advance(_ lines: CGFloat = 1) {
                y += lineHeight * lines
                if y > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
            }
            func draw(_ text: String, _ attributes: [NSAttributedString.Key: Any]? = nil) {
                (text as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attributes ?? body)
                advance()
            }
            context.beginPage()
            draw("\(patient.name) (\(patient.medicalID))", title); advance()
            draw("Date of birth: \(patient.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not recorded")")
            draw("Gender: \(patient.gender)")
            draw("Blood type: \(patient.bloodType)")
            if !patient.examinationType.isEmpty { draw("Examination: \(patient.examinationType)") }
            if !patient.allergies.isEmpty { draw("Allergies: \(patient.allergies)") }
            if !patient.medications.isEmpty { draw("Medications: \(patient.medications)") }
            if !patient.conditions.isEmpty { draw("Conditions: \(patient.conditions)") }
            advance()
            draw("Vitals readings (\(patient.vitals.count))", section)
            draw("All entries are synthetic prototype data. Reference ranges are illustrative adult values.")
            for reading in patient.vitals.sorted(by: { $0.date < $1.date }) {
                advance()
                draw(reading.date.formatted(date: .abbreviated, time: .shortened), section)
                for metric in VitalMetric.allCases where reading.values[metric] != nil {
                    let value = reading.values[metric]!
                    draw("  \(metric.title): \(format(value)) \(metric.unit)\(metric.isOutsideReference(value) ? " (outside illustrative range)" : "")")
                }
                if let map = reading.meanArterialPressure { draw("  MAP: \(format(map)) mmHg") }
                if !reading.symptoms.isEmpty { draw("  Symptoms: \(reading.symptoms)") }
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("patient-\(patient.medicalID.isEmpty ? patient.id.uuidString : patient.medicalID).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
}
