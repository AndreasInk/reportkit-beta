# UI Validation Notes

The v2 iOS app is validated on iPhone and focuses on three auth states and one signed-in status screen.

- Signed-out screen: verifies sign-in fields, button state, and error handling.
- Signed-in screen: verifies token status block, refresh button, and sign-out action.
- Launch path: verifies the `.launching` state transitions to sign-out when unauthenticated.

## Current Status

- Full-screen signed-out flow renders in the current prototype layout.
- Signed-in preview state remains stable with static token fields for inspection.
- No pairing, scanner, or pairing-token screens remain in the flow.

## Next checks

- Add one screenshot pass for launch/login on a physical iPhone.
- Add widget rendering pass for `.good`, `.warning`, and `.critical` states.
