import CryptoKit
import Foundation
import Observation
import Security
import SwiftData

@Model
final class EncryptedPatientRecord {
    @Attribute(.unique) var id: UUID
    var payload: Data

    init(id: UUID, payload: Data) {
        self.id = id
        self.payload = payload
    }
}

enum StorageError: LocalizedError {
    case keychain(OSStatus)
    case invalidKey
    case encryption
    case invalidProfile
    case duplicateID

    var errorDescription: String? {
        switch self {
        case .keychain: "Secure storage is unavailable. Unlock your device and try again."
        case .invalidKey: "The encryption key is invalid. Existing data has not been modified."
        case .encryption: "Unable to encrypt the patient record."
        case .invalidProfile: "The profile or reading contains invalid values. Review the form."
        case .duplicateID: "A patient with this medical ID already exists."
        }
    }
}

enum PatientEncryption {
    static func loadKey() throws -> SymmetricKey {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "PatientHealth.LocalEncryption",
            kSecAttrAccount as String: "patient-data-key"
        ]
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &result)
        if status == errSecSuccess {
            guard let data = result as? Data, data.count == 32 else { throw StorageError.invalidKey }
            return SymmetricKey(data: data)
        }
        guard status == errSecItemNotFound else { throw StorageError.keychain(status) }
        let key = SymmetricKey(size: .bits256)
        var insert = query
        insert[kSecValueData as String] = key.withUnsafeBytes { Data($0) }
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let insertStatus = SecItemAdd(insert as CFDictionary, nil)
        guard insertStatus == errSecSuccess else { throw StorageError.keychain(insertStatus) }
        return key
    }

    static func seal(_ patient: Patient, key: SymmetricKey) throws -> Data {
        let data = try JSONEncoder().encode(patient)
        guard let encrypted = try AES.GCM.seal(data, using: key, authenticating: Data(patient.id.uuidString.utf8)).combined else {
            throw StorageError.encryption
        }
        return encrypted
    }

    static func open(_ payload: Data, id: UUID, key: SymmetricKey) throws -> Patient {
        let box = try AES.GCM.SealedBox(combined: payload)
        let data = try AES.GCM.open(box, using: key, authenticating: Data(id.uuidString.utf8))
        let patient = try JSONDecoder().decode(Patient.self, from: data)
        guard patient.id == id else { throw StorageError.invalidProfile }
        return patient
    }
}

@MainActor @Observable
final class PatientStore {
    private(set) var patients: [Patient] = []
    private let context: ModelContext
    private let key: SymmetricKey

    init(container: ModelContainer, key: SymmetricKey) throws {
        context = ModelContext(container)
        context.autosaveEnabled = false
        self.key = key
        let records = try context.fetch(FetchDescriptor<EncryptedPatientRecord>())
        patients = try records.map { try PatientEncryption.open($0.payload, id: $0.id, key: key) }
        patients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ patient: Patient) throws {
        guard patient.validationErrors().isEmpty,
              patient.vitals.allSatisfy({ $0.validationErrors(birthDate: patient.birthDate).isEmpty }) else {
            throw StorageError.invalidProfile
        }
        let medicalID = patient.medicalID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !patients.contains(where: {
            $0.id != patient.id && $0.medicalID.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(medicalID) == .orderedSame
        }) else { throw StorageError.duplicateID }
        let payload = try PatientEncryption.seal(patient, key: key)
        let id = patient.id
        let request = FetchDescriptor<EncryptedPatientRecord>(predicate: #Predicate { $0.id == id })
        do {
            if let record = try context.fetch(request).first {
                record.payload = payload
            } else {
                context.insert(EncryptedPatientRecord(id: id, payload: payload))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        patients.removeAll { $0.id == patient.id }
        patients.append(patient)
        patients.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func addReading(_ reading: VitalReading, to patientID: UUID) throws {
        guard var patient = patients.first(where: { $0.id == patientID }) else { throw StorageError.invalidProfile }
        patient.vitals.append(reading)
        try save(patient)
    }

    func deletePatient(_ patientID: UUID) throws {
        let request = FetchDescriptor<EncryptedPatientRecord>(predicate: #Predicate { $0.id == patientID })
        do {
            for record in try context.fetch(request) { context.delete(record) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        patients.removeAll { $0.id == patientID }
    }

    func deleteReading(_ readingID: UUID, from patientID: UUID) throws {
        guard var patient = patients.first(where: { $0.id == patientID }) else { throw StorageError.invalidProfile }
        patient.vitals.removeAll { $0.id == readingID }
        try save(patient)
    }
}
