# PatientHealth (iOS)

Native iOS patient-health prototype built with SwiftUI, Observation, SwiftData, Charts, CryptoKit, and Security. No third-party dependencies.

> Synthetic-data-only local prototype. Do not use real patient data. No backend/FHIR integration, authentication, or compliance certification is implemented.

## Requirements

- Xcode 16+
- iOS 17.0+ deployment target

## Getting started

1. Open `PatientHealth.xcodeproj`.
2. Select the shared `PatientHealth` scheme and an iOS Simulator.
3. Build and run.

Debug, QA, and Release configurations use separate bundle identifiers. Physical-device signing requires a developer team chosen by the project owner.

## Build

```sh
xcodebuild build -project PatientHealth.xcodeproj -scheme PatientHealth -destination 'generic/platform=iOS Simulator'
```

## Test

```sh
xcodebuild test -project PatientHealth.xcodeproj -scheme PatientHealth -destination 'platform=iOS Simulator,name=iPhone 17'
```

Do not pass `CODE_SIGNING_ALLOWED=NO`; unsigned simulator builds cannot access Keychain.

## Security

Patient payloads are AES-GCM encrypted before SwiftData persistence. The key is stored in Keychain with `WhenUnlockedThisDeviceOnly` access and is not backed up or synchronized.

## Documentation

- `requirements.md` – product requirements
- `todo.md` – task list
- `AGENTS.md` – development notes
