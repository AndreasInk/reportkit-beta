# iOS

This folder contains the ReportKit Beta iPhone app, widget extension, shared Live Activity types, and the Xcode project.

## What Lives Here

- `App/`: app entry point, auth flow, onboarding, token sync, and supporting app logic
- `Widget/`: Live Activity and widget extension sources
- `Shared/`: shared types and assets used across targets
- `ReportKitSimple.xcodeproj/`: Xcode project
- `project.yml`: XcodeGen project definition

## User Flow

1. Launch the app.
2. Complete onboarding on first launch.
3. Sign in with the same Supabase email/password used by the CLI.
4. Grant notification permission.
5. Let the app upload Live Activity tokens.

## Config

The app reads these `Info.plist` keys:

- `REPORTKIT_SUPABASE_URL`
- `REPORTKIT_SUPABASE_ANON_KEY`

Placeholder values should be treated as invalid.

## Targets

- `ReportKitSimple`: iPhone app
- `ReportKitSimpleWidgetExtension`: widget and Live Activity extension
- `ReportKitSimpleTests`: unit tests
- `ReportKitSimpleUITests`: UI tests

## Notes

- Shared Live Activity attributes live in `Shared/ReportKitSimpleAttributes.swift`.
- The app should remain in the signed-out flow until the user has valid auth.
- Token upload is part of the signed-in app experience, not a separate pairing flow.
