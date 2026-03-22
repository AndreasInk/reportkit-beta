# UI Validation Notes

The v2 iOS app is validated on iPhone and focuses on three auth states and one signed-in status screen.

- Signed-out screen: verifies onboarding pager and auth transition behavior.
- Signed-in screen: verifies token status block, refresh button, and sign-out action.
- Launch path: verifies the `.launching` state transitions to sign-out when unauthenticated.

## Current Status

- Full-screen signed-out onboarding flow renders with 3-step pager controls.
- Signed-in preview state remains stable with static token fields for inspection.
- No pairing, scanner, or pairing-token screens remain in the flow.

## Onboarding UI Iteration Cycles (2026-03-21)

Cycle 1:
- Change validated: first-launch signed-out route now shows onboarding step 1 with `Skip`, `Continue`, disabled `Back`, and progress indicator.
- Validation method: simulator UI test (`testFirstLaunchShowsOnboardingPagerControls`) plus local preview definitions in `ReportKitSimpleViews.swift`.

Cycle 2:
- Change validated: advancing through steps reaches auth in sign-up mode on final CTA.
- Validation method: simulator UI test (`testContinueThroughOnboardingLandsInSignUp`) verifying three `Continue/Get Started` taps end on `sign-up-button`.

Cycle 3:
- Change validated: signed-out auth contains `View intro again` and returns to onboarding without forcing app reset.
- Validation method: simulator UI test (`testViewIntroAgainReturnsToOnboarding`) verifying auth -> intro loop.

Note:
- Preview-first was attempted via Xcode `RenderPreview`, but tool calls timed out in this environment; simulator UI validation was used as fallback for all three cycles.
