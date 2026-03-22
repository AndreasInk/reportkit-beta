import Foundation

enum ReportKitSimpleConfig {
    static var supabaseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "REPORTKIT_SUPABASE_URL") as? String,
            let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            preconditionFailure("Missing REPORTKIT_SUPABASE_URL")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REPORTKIT_SUPABASE_ANON_KEY") as? String else {
            preconditionFailure("Missing REPORTKIT_SUPABASE_ANON_KEY")
        }
        return key
    }

    static var apnsEnv: String {
        (Bundle.main.object(forInfoDictionaryKey: "REPORTKIT_APNS_ENV") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "sandbox"
    }
}
