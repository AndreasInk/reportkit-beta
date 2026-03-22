import Foundation

enum ReportKitSimpleConfig {
    private static func requiredInfoValue(_ key: String) -> String {
        if let envValue = ProcessInfo.processInfo.environment[key] {
            let trimmed = envValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !trimmed.contains("$(") {
                return trimmed
            }
        }

        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !raw.contains("$(")
        else {
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                switch key {
                case "REPORTKIT_SUPABASE_URL":
                    return "https://example.supabase.co"
                case "REPORTKIT_SUPABASE_ANON_KEY":
                    return "test-anon-key"
                default:
                    break
                }
            }
            preconditionFailure("Missing or unresolved config key: \(key)")
        }

        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var supabaseURL: URL {
        guard let url = URL(string: requiredInfoValue("REPORTKIT_SUPABASE_URL")) else {
            preconditionFailure("Invalid URL for REPORTKIT_SUPABASE_URL")
        }
        return url
    }

    static var supabaseAnonKey: String {
        return requiredInfoValue("REPORTKIT_SUPABASE_ANON_KEY")
    }

    static var apnsEnv: String {
        (Bundle.main.object(forInfoDictionaryKey: "REPORTKIT_APNS_ENV") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "sandbox"
    }
}
