import Foundation
import Operation_iOS
import SDKLogger
import NovaAppAttest
import NovaOperationSupport

struct AnalyticsGateway {
    let attestation: BackendAttestationProviderProtocol
    let uploadFactory: AnalyticsUploadOperationFactoryProtocol
    let attestationSource: AnalyticsAttestationProviding
}

protocol AnalyticsGatewayResolving: AnyObject {
    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway>
}

final class AnalyticsGatewayResolver: AnalyticsGatewayResolving {
    private let attestationSource: AnalyticsAttestationProviding
    private let logger: SDKLoggerProtocol

    private let mutex = NSLock()
    private var gateway: AnalyticsGateway?

    init(attestationSource: AnalyticsAttestationProviding, logger: SDKLoggerProtocol) {
        self.attestationSource = attestationSource
        self.logger = logger
    }

    var resolved: AnalyticsGateway? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return gateway
    }

    func createGatewayWrapper() -> CompoundOperationWrapper<AnalyticsGateway> {
        if let resolved {
            return .createWithResult(resolved)
        }

        let attestationWrapper = attestationSource.createAttestationWrapper()

        let mapOperation = ClosureOperation<AnalyticsGateway> { [weak self] in
            let attestation = try attestationWrapper.targetOperation.extractNoCancellableResultData()

            guard let self else {
                throw BackendAttestationError.unsupported
            }

            return build(attestation: attestation)
        }

        mapOperation.addDependency(attestationWrapper.targetOperation)

        return attestationWrapper.insertingTail(operation: mapOperation)
    }
}

// MARK: - Private

private extension AnalyticsGatewayResolver {
    func build(attestation: AnalyticsAttestation) -> AnalyticsGateway {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let gateway {
            return gateway
        }

        let built = AnalyticsGateway(
            attestation: attestation.provider,
            uploadFactory: AnalyticsUploadOperationFactory(baseURL: attestation.gatewayURL, logger: logger),
            attestationSource: attestationSource
        )

        gateway = built

        return built
    }
}
