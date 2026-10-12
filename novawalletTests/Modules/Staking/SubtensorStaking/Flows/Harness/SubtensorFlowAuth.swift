import Foundation
import NovaAuth
@testable import novawallet

final class SubtensorFlowAuth {
    let harness: HostAuthHarness
    let provider: HostAuthProvider

    init(clock: SubtensorFlowClock) throws {
        harness = try HostAuthHarness(protocolClass: SubtensorFlowURLProtocol.self, clock: HostAuthClock(value: { clock.now }))
        provider = try HostAuthProvider(client: harness.client)
    }
}
