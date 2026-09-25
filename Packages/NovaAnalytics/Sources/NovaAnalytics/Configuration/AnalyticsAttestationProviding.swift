import Foundation
import Operation_iOS
import NovaAppAttest

public struct AnalyticsAttestation {
    public let gatewayURL: URL
    public let provider: BackendAttestationProviderProtocol

    public init(gatewayURL: URL, provider: BackendAttestationProviderProtocol) {
        self.gatewayURL = gatewayURL
        self.provider = provider
    }
}

public protocol AnalyticsAttestationProviding: AnyObject {
    func createAttestationWrapper() -> CompoundOperationWrapper<AnalyticsAttestation>

    func createExclusiveWrapper<T>(
        _ exchangeClosure: @escaping () throws -> CompoundOperationWrapper<T>
    ) -> CompoundOperationWrapper<T>
}
