import Foundation
import Testing
@testable import ReportKitSimple

struct ReportKitSimpleTests {
    @Test("Login flow exposes email status")
    func signedInPhaseTracksUserEmail() {
        let session = UserSessionSnapshot(userID: "demo-user", email: "demo@example.com")
        let model = ReportKitSimpleAppModel()
        model.phase = .signedIn(session)

        #expect(session.email == "demo@example.com")
        #expect(session.userID == "demo-user")
    }

    @Test("ReportKit attributes retain minimal fields")
    func liveActivityStateContainsSimpleContract() {
        let state = ReportKitSimpleAttributes.ContentState.preview
        #expect(state.title == "Daily Pulse")
        #expect(state.summary == "Revenue is steady. Trial-to-paid dipped after yesterday's paywall experiment.")
        #expect(state.status == .warning)
    }

    @Test("Live Activity state preserves minimal fields")
    func liveActivityState() {
        let state = ReportKitSimpleAttributes.ContentState.preview
        #expect(state.title == "Daily Pulse")
        #expect(state.status == .warning)
        #expect(state.action == "Review the new paywall copy before noon.")
    }
}
