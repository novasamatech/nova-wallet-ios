import Foundation

struct NovaAuthRefusal: Codable, Equatable {
    static let delays: [TimeInterval] = [3600, 21600, 86400]

    let deadline: NovaAuthTime
    let failures: Int
    let appVersion: String

    init(now: NovaAuthTime, previous: NovaAuthRefusal?, appVersion: String) {
        let repeated = previous.flatMap { $0.appVersion == appVersion ? $0.failures : nil } ?? 0
        failures = min(repeated + 1, Self.delays.count)
        deadline = NovaAuthTime(
            bootID: now.bootID,
            continuousSeconds: now.continuousSeconds + Self.delays[failures - 1]
        )
        self.appVersion = appVersion
    }

    func check(now: NovaAuthTime, appVersion: String) throws {
        guard self.appVersion == appVersion, deadline.bootID == now.bootID,
              deadline.continuousSeconds > now.continuousSeconds else { return }
        throw NovaAuthError.cooldown(retryAfter: deadline.continuousSeconds - now.continuousSeconds)
    }
}
