import SwiftUI

struct PatientListView: View {
    let store: PatientStore
    @State private var search = ""
    @State private var addingPatient = false

    private var filteredPatients: [Patient] {
        store.patients.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.medicalID.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Local prototype · synthetic data only", systemImage: "shield.lefthalf.filled")
                        .font(.footnote)
                    Text("Not connected to a clinical backend. Reference ranges are illustrative adult values, not medical advice.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Patients") {
                    ForEach(filteredPatients) { patient in
                        NavigationLink(value: patient.id) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(patient.name).font(.headline)
                                Text("ID: \(patient.medicalID)").font(.subheadline).foregroundStyle(.secondary)
                                Text("\(patient.vitals.count) readings").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .overlay {
                if store.patients.isEmpty {
                    ContentUnavailableView("No patients yet", systemImage: "person.crop.rectangle.badge.plus", description: Text("Tap Add patient to create a synthetic patient profile."))
                } else if filteredPatients.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .navigationTitle("Patient Health")
            .searchable(text: $search, prompt: "Name or medical ID")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add patient", systemImage: "plus") { addingPatient = true }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                PatientDetailView(store: store, patientID: id)
            }
            .sheet(isPresented: $addingPatient) { PatientFormView(store: store, patient: Patient()) }
        }
    }
}

struct PatientFormView: View {
    let store: PatientStore
    @State var patient: Patient
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    @State private var choosingBirthDate = false
    @State private var birthDateDraft = Date()
    private let examinationTypes = Patient.examinationTypes
    private var errors: [String] { patient.validationErrors() }

    var body: some View {
        NavigationStack {
            Form {
                Section("Demographics") {
                    TextField("First name", text: $patient.firstName).textContentType(.givenName)
                    TextField("Last name", text: $patient.lastName).textContentType(.familyName)
                    TextField("Medical ID", text: $patient.medicalID).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        birthDateDraft = patient.birthDate ?? Date()
                        choosingBirthDate = true
                    } label: {
                        LabeledContent("Date of birth", value: patient.birthDate?.formatted(date: .abbreviated, time: .omitted) ?? "Select date")
                    }
                    .accessibilityIdentifier("birthDateButton")
                    Picker("Administrative gender", selection: $patient.gender) {
                        ForEach(["unknown", "female", "male", "other"], id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    TextField("Ethnicity (optional)", text: $patient.ethnicity)
                }
                Section("Contact") {
                    TextField("Phone", text: $patient.phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                    TextField("Email", text: $patient.email).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section("Clinical details") {
                    Picker("Blood type", selection: $patient.bloodType) {
                        ForEach(["Unknown", "A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"], id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Allergies", text: $patient.allergies, axis: .vertical)
                    TextField("Medications", text: $patient.medications, axis: .vertical)
                    TextField("Health conditions", text: $patient.conditions, axis: .vertical)
                }
                Section("Examination") {
                    TextField("Purpose", text: $patient.examinationPurpose)
                    Picker("Type of examination", selection: $patient.examinationType) {
                        Text("Select examination type").tag("")
                        ForEach(examinationTypes, id: \.self) {
                            Text($0).tag($0)
                        }
                        if !patient.examinationType.isEmpty && !examinationTypes.contains(patient.examinationType) {
                            Text("Previous value: \(patient.examinationType)").tag(patient.examinationType)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("examinationTypePicker")
                    TextField("Performed by", text: $patient.performedBy)
                    TextField("Referred by", text: $patient.referredBy)
                }
                Section {
                    Toggle("Consent to local profile storage", isOn: $patient.consentGranted)
                } footer: {
                    Text("Prototype consent flag only. Formal consent records, revocation workflows, and clinical authorization are not implemented.")
                }
                if !errors.isEmpty {
                    Section("Before saving") {
                        ForEach(errors, id: \.self) { Text($0).foregroundStyle(.red) }
                    }
                }
            }
            .navigationTitle(store.patients.contains(where: { $0.id == patient.id }) ? "Edit patient" : "New patient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try store.save(patient)
                            dismiss()
                        } catch let error as StorageError {
                            errorMessage = error.errorDescription
                        } catch {
                            errorMessage = "Unable to save securely. Please retry."
                        }
                    }.disabled(!errors.isEmpty)
                }
            }
            .sheet(isPresented: $choosingBirthDate) {
                NavigationStack {
                    Form {
                        DatePicker("Date of birth", selection: $birthDateDraft, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                    .navigationTitle("Date of birth")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { choosingBirthDate = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Use date") {
                                patient.birthDate = Calendar.current.startOfDay(for: birthDateDraft)
                                choosingBirthDate = false
                            }
                        }
                    }
                }
            }
            .alert("Unable to save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }
}
