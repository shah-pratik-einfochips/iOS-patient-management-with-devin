import SwiftData
import SwiftUI

@main
struct PatientHealthApp: App {
    @State private var store: PatientStore?
    @State private var storageFailed = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if let store {
                        PatientListView(store: store)
                    } else if storageFailed {
                        ContentUnavailableView {
                            Label("Storage unavailable", systemImage: "lock.trianglebadge.exclamationmark")
                        } description: {
                            Text("Patient data could not be opened securely. No records have been reset. Unlock your device and retry.")
                        } actions: {
                            Button("Retry", action: openStorage)
                        }
                    } else {
                        ProgressView("Opening secure storage")
                    }
                }
                if scenePhase != .active {
                    Color(.systemBackground).ignoresSafeArea()
                    Label("Patient Health", systemImage: "lock.shield")
                        .font(.title2)
                }
            }
            .task { if store == nil { openStorage() } }
        }
    }

    private func openStorage() {
        do {
            let container = try ModelContainer(for: EncryptedPatientRecord.self)
            store = try PatientStore(container: container, key: PatientEncryption.loadKey())
            storageFailed = false
        } catch {
            storageFailed = true
        }
    }
}
