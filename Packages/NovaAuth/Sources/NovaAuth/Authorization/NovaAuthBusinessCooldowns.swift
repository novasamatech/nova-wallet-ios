import Foundation

struct NovaAuthBusinessCooldowns {
    private var analytics = NovaAuthCooldown()
    private var bittensor = NovaAuthCooldown()

    func check(request: NovaAuthRequest, now: NovaAuthTime) throws {
        try cooldown(for: request).check(now: now)
    }

    mutating func clear() {
        analytics.clear()
        bittensor.clear()
    }

    @discardableResult mutating func receive(
        _ result: Result<NovaAuthResponse, Error>,
        request: NovaAuthRequest,
        now: NovaAuthTime,
        random: Double,
        origin: inout NovaAuthCooldown
    ) -> TimeInterval? {
        var service = cooldown(for: request)
        var appliedDeadline: NovaAuthTime?
        switch result {
        case let .success(response):
            let status = response.response.statusCode
            let code = NovaAuthWire.errorCode(from: response.body)
            if status == 429 || (status == 500 && code == nil) ||
                (status == 503 && code == "attestation_unavailable") {
                origin.fail(
                    now: now, random: random,
                    retryAfter: NovaAuthWire.retryAfter(response.response) ?? (status == 429 ? 30 : nil)
                )
                appliedDeadline = origin.deadline
            } else if (500 ... 599).contains(status) {
                service.fail(now: now, random: random, retryAfter: NovaAuthWire.retryAfter(response.response))
                appliedDeadline = service.deadline
            } else if (200 ..< 400).contains(status) {
                service.succeed(now: now)
                origin.succeed(now: now)
            }
        case let .failure(error):
            if case .transport = NovaAuth.safeError(error) {
                service.fail(now: now, random: random)
                appliedDeadline = service.deadline
            }
        }
        if request.path == "/v1/analytics/events" { analytics = service }
        else { bittensor = service }
        return appliedDeadline.map { max(0, $0.continuousSeconds - now.continuousSeconds) }
    }

    private func cooldown(for request: NovaAuthRequest) -> NovaAuthCooldown {
        request.path == "/v1/analytics/events" ? analytics : bittensor
    }
}
