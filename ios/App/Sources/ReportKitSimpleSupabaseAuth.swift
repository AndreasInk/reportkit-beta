import Foundation
import Supabase

actor ReportKitSimpleSupabaseAuth: ReportKitSimpleAuthenticating {
    static let shared = ReportKitSimpleSupabaseAuth()

    private var cachedClient: SupabaseClient?

    func currentSession() async -> UserSessionSnapshot? {
        guard let client = try? client(), let session = try? await client.auth.session else {
            return nil
        }

        return UserSessionSnapshot(
            userID: session.user.id.uuidString,
            email: session.user.email ?? ""
        )
    }

    func signIn(email: String, password: String) async throws -> UserSessionSnapshot {
        let client = try client()
        let session = try await client.auth.signIn(email: email, password: password)
        return UserSessionSnapshot(
            userID: session.user.id.uuidString,
            email: session.user.email ?? email
        )
    }

    func signUp(email: String, password: String) async throws -> UserSessionSnapshot? {
        let client = try client()
        let response = try await client.auth.signUp(email: email, password: password)

        if let session = response.session {
            return UserSessionSnapshot(
                userID: session.user.id.uuidString,
                email: session.user.email ?? email
            )
        }

        return nil
    }

    func signOut() async {
        guard let client = try? client() else { return }
        try? await client.auth.signOut()
    }

    func validAccessToken() async throws -> String {
        let client = try client()
        if let session = try? await client.auth.session,
           Date(timeIntervalSince1970: session.expiresAt) > Date().addingTimeInterval(60) {
            return session.accessToken
        }
        let refreshed = try await client.auth.refreshSession()
        return refreshed.accessToken
    }

    func invokeAuthenticatedFunction<Body: Encodable, Response: Decodable>(
        _ name: String,
        body: Body,
        responseType: Response.Type
    ) async throws -> Response {
        let client = try client()
        let token = try await validAccessToken()
        client.functions.setAuth(token: token)

        return try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(method: .post, body: body),
            decode: { data, _ in
                try JSONDecoder.reportKitSimple.decode(Response.self, from: data)
            }
        )
    }

    func invokeAuthenticatedFunction<Body: Encodable>(
        _ name: String,
        body: Body
    ) async throws {
        let client = try client()
        let token = try await validAccessToken()
        client.functions.setAuth(token: token)
        _ = try await client.functions.invoke(
            name,
            options: FunctionInvokeOptions(method: .post, body: body),
            decode: { _, _ in EmptyResponse() }
        )
    }

    private func client() throws -> SupabaseClient {
        if let cachedClient {
            return cachedClient
        }

        let client = SupabaseClient(
            supabaseURL: try ReportKitSimpleConfig.supabaseURL,
            supabaseKey: try ReportKitSimpleConfig.supabaseAnonKey
        )
        cachedClient = client
        return client
    }
}

private struct EmptyResponse: Decodable {}

extension JSONDecoder {
    static let reportKitSimple: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
