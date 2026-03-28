import Foundation

enum ReportKitSimpleConfigError: LocalizedError, Equatable {
    case missingOrUnresolvedKey(String)
    case invalidURL(String)

    var errorDescription: String? {
        switch self {
        case .missingOrUnresolvedKey(let key):
            return "Missing or unresolved configuration key: \(key)."
        case .invalidURL(let key):
            return "Invalid URL in configuration key: \(key)."
        }
    }
}

enum ReportKitSimpleConfig {
    struct Source {
        let environment: [String: String]
        let infoDictionary: [String: Any]
        let isRunningTests: Bool

        static var live: Source {
            Source(
                environment: ProcessInfo.processInfo.environment,
                infoDictionary: Bundle.main.infoDictionary ?? [:],
                isRunningTests: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            )
        }
    }

    static func requiredValue(_ key: String, source: Source = .live) throws -> String {
        if let envValue = source.environment[key] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.contains("$(") {
                return trimmed
            }
        }

        guard
            let raw = source.infoDictionary[key] as? String,
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !raw.contains("$(")
        else {
            if source.isRunningTests {
                switch key {
                case "REPORTKIT_SUPABASE_URL":
                    return "https://example.supabase.co"
                case "REPORTKIT_SUPABASE_ANON_KEY":
                    return "test-anon-key"
                default:
                    break
                }
            }
            throw ReportKitSimpleConfigError.missingOrUnresolvedKey(key)
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var supabaseURL: URL {
        get throws {
            guard let url = URL(string: try requiredValue("REPORTKIT_SUPABASE_URL")) else {
                throw ReportKitSimpleConfigError.invalidURL("REPORTKIT_SUPABASE_URL")
            }
            return url
        }
    }

    static var supabaseAnonKey: String {
        get throws {
            try requiredValue("REPORTKIT_SUPABASE_ANON_KEY")
        }
    }

    static var apnsEnv: String {
        (Bundle.main.object(forInfoDictionaryKey: "REPORTKIT_APNS_ENV") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "sandbox"
    }
}
