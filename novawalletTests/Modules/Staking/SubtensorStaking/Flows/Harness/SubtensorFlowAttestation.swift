import Foundation
import Cuckoo
import NovaAppAttest
import Operation_iOS
@testable import novawallet

final class SubtensorFlowAttestation {
    struct Signature: Equatable {
        let target: AttestationRequestTarget
        let body: Data
        let headers: [String: String]
    }

    static let clientId = "flow-client"

    let provider = MockBackendAttestationProviderProtocol()
    let holder = MockBittensorAttestationHolderProtocol()

    private let lock = NSLock()
    private var recordedSignatures: [Signature] = []

    init() {
        let endpoint = BackendAttestationEndpoint(gatewayURL: SubtensorFlowHost.bittensorGateway, provider: provider)

        stub(holder) { stub in
            when(stub.createEndpointWrapper()).then {
                CompoundOperationWrapper.createWithResult(endpoint)
            }
        }

        stub(provider) { stub in
            when(stub.createSignedHeadersWrapper(target: any(), bodyClosure: any())).then { [weak self] target, bodyClosure in
                let headers = self?.sign(target: target, body: (try? bodyClosure()) ?? Data("unreadable".utf8))

                return CompoundOperationWrapper.createWithResult(headers)
            }

            when(stub.markUnattested(ifCurrentClientId: any())).thenDoNothing()
        }
    }

    var signatures: [Signature] {
        lock.lock()
        defer { lock.unlock() }
        return recordedSignatures
    }
}

private extension SubtensorFlowAttestation {
    func sign(target: AttestationRequestTarget, body: Data) -> [AttestationHeaderKey: String] {
        lock.lock()
        defer { lock.unlock() }

        let number = recordedSignatures.count + 1

        let headers: [AttestationHeaderKey: String] = [
            .profile: "2",
            .clientId: Self.clientId,
            .challenge: "challenge-\(number)",
            .appAttestAssertion: "assertion-\(number)"
        ]

        let rawHeaders = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.rawValue, $0.value) })

        recordedSignatures.append(Signature(target: target, body: body, headers: rawHeaders))

        return headers
    }
}
