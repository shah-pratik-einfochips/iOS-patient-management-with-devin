import SwiftUI

struct VitalsFormView: View {
    let store: PatientStore
    let patient: Patient
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var inputs: [VitalMetric: String] = [:]
    @State private var symptoms = ""
    @State private var heightUnit = "cm"
    @State private var weightUnit = "kg"
    @State private var temperatureUnit = "C"
    @State private var inches = ""
    @State private var errorMessage: String?

    private func number(_ text: String) -> Double? {
        DecimalInput.parse(text)
    }

    private var reading: VitalReading {
        var values: [VitalMetric: Double] = [:]
        for metric in VitalMetric.allCases {
            guard let raw = inputs[metric], let value = number(raw) else { continue }
            switch metric {
            case .height where heightUnit == "ft/in": values[metric] = UnitConversion.centimeters(feet: value, inches: number(inches) ?? 0)
            case .weight where weightUnit == "lbs": values[metric] = UnitConversion.kilograms(pounds: value)
            case .temperature where temperatureUnit == "F": values[metric] = UnitConversion.celsius(fahrenheit: value)
            default: values[metric] = value
            }
        }
        return VitalReading(date: date, values: values, symptoms: symptoms)
    }

    private var errors: [String] {
        var errors = reading.validationErrors(birthDate: patient.birthDate)
        for metric in VitalMetric.allCases {
            if let text = inputs[metric], !text.isEmpty, number(text) == nil { errors.append("Enter a valid number for \(metric.title).") }
        }
        if heightUnit == "ft/in", !inches.isEmpty {
            if let value = number(inches), (0..<12).contains(value), number(inputs[.height] ?? "") != nil {} else {
                errors.append("Enter feet and inches, with inches from 0 to less than 12.")
            }
        }
        return errors
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Reading date", selection: $date, in: (patient.birthDate ?? .distantPast)...Date())
                    Text("Leave unmeasured vitals blank. Blood pressure requires both values.").font(.footnote)
                }
                Section("Vitals") {
                    ForEach(VitalMetric.allCases) { metric in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(metric.title)
                                Spacer()
                                TextField(metric.unit, text: Binding(get: { inputs[metric] ?? "" }, set: { inputs[metric] = $0 }))
                                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .accessibilityLabel(metric.title)
                                    .accessibilityHint("Value in \(displayUnit(metric))")
                            }
                            if metric == .height {
                                unitPicker("Height unit", selection: $heightUnit, units: ["cm", "ft/in"], metric: metric)
                                if heightUnit == "ft/in" {
                                    TextField("Additional inches (0–11.99)", text: $inches).keyboardType(.decimalPad)
                                }
                            } else if metric == .weight {
                                unitPicker("Weight unit", selection: $weightUnit, units: ["kg", "lbs"], metric: metric)
                            } else if metric == .temperature {
                                unitPicker("Temperature unit", selection: $temperatureUnit, units: ["C", "F"], metric: metric)
                            }
                            if let value = reading.values[metric], metric.isOutsideReference(value) {
                                Label("Outside illustrative adult reference range", systemImage: "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                    }
                    if let map = reading.meanArterialPressure {
                        LabeledContent("Calculated MAP", value: "\(map.formatted(.number.precision(.fractionLength(1)))) mmHg")
                    }
                }
                Section("Symptoms") { TextField("Optional symptoms", text: $symptoms, axis: .vertical) }
                Section {
                    Text("Reference ranges are illustrative only, are not age-adjusted, and must not be used for diagnosis or treatment.").font(.footnote)
                }
                if !errors.isEmpty {
                    Section("Before saving") { ForEach(errors, id: \.self) { Text($0).foregroundStyle(.red) } }
                }
            }
            .navigationTitle("Add vitals").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.addReading(reading, to: patient.id)
                            dismiss()
                        } catch { errorMessage = error.localizedDescription }
                    }.disabled(!errors.isEmpty)
                }
            }
            .alert("Unable to save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func displayUnit(_ metric: VitalMetric) -> String {
        switch metric {
        case .height: heightUnit
        case .weight: weightUnit
        case .temperature: temperatureUnit
        default: metric.unit
        }
    }

    private func unitPicker(_ title: String, selection: Binding<String>, units: [String], metric: VitalMetric) -> some View {
        Picker(title, selection: selection) {
            ForEach(units, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: selection.wrappedValue) { _, _ in
            inputs[metric] = ""
            if metric == .height { inches = "" }
        }
    }
}
