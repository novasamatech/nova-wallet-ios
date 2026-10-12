import Foundation

enum NovaAuthRoute {
    static func validate(method: NovaAuthMethod, path: String, body: Data?, contentType: String?) throws {
        if method == .post {
            guard ["/v1/analytics/events", "/v1/bittensor/operations/search"].contains(path),
                  body != nil,
                  contentType == "application/json" || contentType == "application/json; charset=utf-8" else {
                throw NovaAuthError.invalidRequest
            }
            return
        }
        guard body == nil, contentType == nil, isReadPath(path) else { throw NovaAuthError.invalidRequest }
    }

    static func isReadPath(_ path: String) -> Bool {
        let prefix = "/v1/bittensor/profile-3/"
        guard path.hasPrefix(prefix) else { return false }
        let suffix = String(path.dropFirst(prefix.count))
        if ["subnets", "yields/root", "recommendations", "recommendations/subnets"].contains(suffix) { return true }
        let parts = suffix.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 3, parts[0] == "subnets", parts[2] == "validators" { return isNetuid(parts[1]) }
        if parts.count == 4, parts[0] == "subnets", parts[2] == "yields", parts[3] == "alpha" {
            return isNetuid(parts[1])
        }
        if parts.count == 4, parts[0] == "recommendations", parts[1] == "subnets", parts[3] == "validators" {
            return isNetuid(parts[2])
        }
        return false
    }

    private static func isNetuid(_ value: Substring) -> Bool {
        guard let integer = UInt16(value) else { return false }
        return String(integer) == value
    }
}
