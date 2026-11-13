# iOS project

- Open `PatientHealth.xcodeproj` and select the shared `PatientHealth` scheme.
- The app uses SwiftUI, Observation, SwiftData, Charts, CryptoKit, and Security with no third-party dependencies. Minimum deployment target: iOS 17. Xcode 16+ is required for synchronized project groups.
- Debug, QA, and Release configurations have separate bundle identifiers. Physical-device signing requires a developer team chosen by the project owner. Keep Xcode's default ad-hoc signing enabled for simulator builds; a developer team is not required for the simulator.
- Build: `xcodebuild build -project PatientHealth.xcodeproj -scheme PatientHealth -destination 'generic/platform=iOS Simulator'`.
- Tests: `xcodebuild test -project PatientHealth.xcodeproj -scheme PatientHealth -destination 'platform=iOS Simulator,name=iPhone 17'`. Choose an installed simulator if that name is unavailable. The shared scheme enables coverage and includes model/storage unit tests plus `PatientHealthUITests`. UI tests open and cancel unsaved forms without deleting or resetting patient data.
- Never pass `CODE_SIGNING_ALLOWED=NO` when running this app or its tests: unsigned simulator builds cannot access Keychain and fail with OSStatus -34018. The regression suite verifies Keychain key persistence and disk-backed storage initialization.
- `requirements.md` and `todo.md` are read-only specifications. Do not mark tasks complete without explicit permission and verification.
- This is a synthetic-data-only local prototype. No FHIR backend, authentication, formal consent workflow, or compliance certification is implemented. Do not use real patient data.
- Patient payloads are AES-GCM encrypted before SwiftData persistence. The key is held in Keychain with `WhenUnlockedThisDeviceOnly` access. Encryption keys are not backed up or synchronized; data recovery and migration policies remain to be designed.
- New profiles require explicit DOB selection. `Patient.birthDate` is optional for unsaved drafts; existing encoded dates remain readable. Examination choices are centralized in `Patient.examinationTypes`; legacy unlisted values remain visible but must be replaced or cleared before saving.
- Numeric input bounds and adult reference ranges are illustrative, not clinically approved or age-adjusted. Unit conversion and model validation have XCTest coverage.
- Do not introduce plaintext patient logging, embedded backend secrets, or automatic network uploads. Backend endpoint, FHIR version/profile, and authorization flow must be agreed before live integration.
