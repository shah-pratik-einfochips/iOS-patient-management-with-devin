import Charts
import SwiftUI

struct PatientDetailView: View {
    let store: PatientStore
    let patientID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var editingPatient = false
    @State private var addingVitals = false
    @State private var metric: VitalMetric = .heartRate
    @State private var showChart = true
    @State private var selectedDate: Date?
    @State private var deletingPatient = false
    @State private var shareURL: URL?
    @State private var errorMessage: String?

    private var patient: Patient? { store.patients.first { $0.id == patientID } }

    var body: some View {
        if let patient {
            List {
                Section("Patient profile") {
                    LabeledContent("Medical ID", value: patient.medicalID)
                    LabeledContent("Date of birth", value: patient.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not recorded")
                    LabeledContent("Blood type", value: patient.bloodType)
                    if !patient.allergies.isEmpty { LabeledContent("Allergies", value: patient.allergies) }
                    if !patient.medications.isEmpty { LabeledContent("Medications", value: patient.medications) }
                    if !patient.conditions.isEmpty { LabeledContent("Conditions", value: patient.conditions) }
                    if !patient.examinationType.isEmpty { LabeledContent("Examination type", value: patient.examinationType) }
                    if !patient.examinationPurpose.isEmpty { LabeledContent("Purpose", value: patient.examinationPurpose) }
                    if !patient.performedBy.isEmpty { LabeledContent("Performed by", value: patient.performedBy) }
                    if !patient.referredBy.isEmpty { LabeledContent("Referred by", value: patient.referredBy) }
                    Button("Edit profile") { editingPatient = true }
                }
                Section("Last seven days") {
                    Picker("Vital type", selection: $metric) {
                        ForEach(VitalMetric.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("Chart view", isOn: $showChart)
                    let readings = recentReadings(patient)
                    let values = readings.compactMap { $0.values[metric] }
                    if values.isEmpty {
                        Text("No \(metric.title.lowercased()) readings in the last seven days.").foregroundStyle(.secondary)
                    } else {
                        if showChart {
                            Chart(readings) { reading in
                                if let value = reading.values[metric] {
                                    LineMark(x: .value("Date", reading.date), y: .value(metric.title, value))
                                    if let selectedDate, VitalReading.nearest(in: readings, to: selectedDate, metric: metric)?.id == reading.id {
                                        RuleMark(x: .value("Selected reading", reading.date))
                                            .foregroundStyle(.secondary)
                                    }
                                    PointMark(x: .value("Date", reading.date), y: .value(metric.title, value))
                                        .symbol(metric.isOutsideReference(value) ? .diamond : .circle)
                                        .foregroundStyle(metric.isOutsideReference(value) ? .orange : .blue)
                                        .accessibilityLabel("\(reading.date.formatted()), \(metric.title)")
                                        .accessibilityValue("\(value.formatted()) \(metric.unit)\(metric.isOutsideReference(value) ? ", outside illustrative range" : "")")
                                }
                            }
                            .chartYAxisLabel(metric.unit)
                            .chartXSelection(value: $selectedDate)
                            .chartOverlay { proxy in
                                GeometryReader { geometry in
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                        .onTapGesture { location in
                                            guard let frame = proxy.plotFrame else { return }
                                            let plot = geometry[frame]
                                            guard plot.contains(location) else { return }
                                            selectedDate = proxy.value(atX: location.x - plot.origin.x, as: Date.self)
                                        }
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(height: 220)
                            if let selectedDate, let reading = VitalReading.nearest(in: readings, to: selectedDate, metric: metric), let value = reading.values[metric] {
                                LabeledContent("Selected: \(reading.date.formatted(date: .abbreviated, time: .shortened))", value: "\(value.formatted()) \(metric.unit)")
                                if metric.isOutsideReference(value) {
                                    Label("Outside illustrative adult range", systemImage: "exclamationmark.triangle")
                                }
                            }
                            Text("Tap a point to inspect its value.").font(.caption)
                                .onChange(of: metric) { _, _ in selectedDate = nil }
                        }
                        LabeledContent("Average", value: "\((values.reduce(0, +) / Double(values.count)).formatted(.number.precision(.fractionLength(1)))) \(metric.unit)")
                        LabeledContent("Minimum / maximum", value: "\((values.min() ?? 0).formatted()) / \((values.max() ?? 0).formatted()) \(metric.unit)")
                        ForEach(readings.reversed()) { reading in
                            if let value = reading.values[metric] {
                                VStack(alignment: .leading) {
                                    LabeledContent(reading.date.formatted(date: .abbreviated, time: .shortened), value: "\(value.formatted()) \(metric.unit)")
                                    if metric.isOutsideReference(value) {
                                        Label("Outside illustrative adult range", systemImage: "exclamationmark.triangle")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    Text("Illustrative adult ranges only. Not clinical decision support.").font(.caption).foregroundStyle(.secondary)
                }
                Section("All readings") {
                    if patient.vitals.isEmpty { Text("No vitals recorded yet.").foregroundStyle(.secondary) }
                    ForEach(patient.vitals.sorted { $0.date > $1.date }) { reading in
                        DisclosureGroup(reading.date.formatted(date: .abbreviated, time: .shortened)) {
                            ForEach(VitalMetric.allCases) { metric in
                                if let value = reading.values[metric] {
                                    LabeledContent(metric.title, value: "\(value.formatted()) \(metric.unit)")
                                }
                            }
                            if let map = reading.meanArterialPressure { LabeledContent("MAP", value: "\(map.formatted()) mmHg") }
                            if !reading.symptoms.isEmpty { Text(reading.symptoms) }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                do {
                                    try store.deleteReading(reading.id, from: patient.id)
                                } catch { errorMessage = "Unable to delete the reading. Please retry." }
                            }
                        }
                    }
                }
            }
            .navigationTitle(patient.name)
            .toolbar {
                Button("Add vitals", systemImage: "plus") { addingVitals = true }
                Menu("More", systemImage: "ellipsis") {
                    Button("Export CSV") { export(patient, pdf: false) }
                    Button("Export PDF") { export(patient, pdf: true) }
                    Button("Delete patient", role: .destructive) { deletingPatient = true }
                }
            }
            .confirmationDialog("Delete \(patient.name) and all recorded vitals?", isPresented: $deletingPatient, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    do {
                        try store.deletePatient(patient.id)
                        dismiss()
                    } catch { errorMessage = "Unable to delete the patient. Please retry." }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $editingPatient) { PatientFormView(store: store, patient: patient) }
            .sheet(isPresented: $addingVitals) { VitalsFormView(store: store, patient: patient) }
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL { ShareSheet(items: [shareURL]) }
            }
            .alert("Unable to complete", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        } else {
            ContentUnavailableView("Patient unavailable", systemImage: "person.crop.circle.badge.questionmark")
        }
    }

    private func export(_ patient: Patient, pdf: Bool) {
        do {
            shareURL = pdf ? try PatientExport.pdfURL(patient) : try PatientExport.csvURL(patient)
        } catch { errorMessage = "The export could not be created. Please retry." }
    }

    private func recentReadings(_ patient: Patient) -> [VitalReading] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: now)) ?? now
        return patient.vitals.filter { $0.date >= start && $0.date <= now }.sorted { $0.date < $1.date }
    }
}
