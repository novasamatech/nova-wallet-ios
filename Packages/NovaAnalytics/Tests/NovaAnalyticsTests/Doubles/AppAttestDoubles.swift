import Foundation
import Operation_iOS
import NovaAppAttest

final class DeviceCheckAttestingSpy: DeviceCheckAttesting {
    let isSupported = true

    private let recordedGenerateKeyCalls = Locked(0)

    var generateKeyCallCount: Int { recordedGenerateKeyCalls.value }

    func reset() {
        recordedGenerateKeyCalls.update { $0 = 0 }
    }

    func generateKey(completionHandler: @escaping (String?, Error?) -> Void) {
        recordedGenerateKeyCalls.update { $0 += 1 }
        completionHandler(UUID().uuidString, nil)
    }

    func attestKey(
        _: String,
        clientDataHash _: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        completionHandler(Data("attestation".utf8), nil)
    }

    func generateAssertion(
        _: String,
        clientDataHash _: Data,
        completionHandler: @escaping (Data?, Error?) -> Void
    ) {
        completionHandler(Data("assertion".utf8), nil)
    }
}

final class BackendAttestationRemoteFactorySpy: BackendAttestationRemoteFactoryProtocol {
    func createChallengeWrapper() -> CompoundOperationWrapper<String> {
        .createWithResult(UUID().uuidString)
    }

    func createRegisterOperation(
        _ requestClosure: @escaping () throws -> BackendAttestationRegisterRequest
    ) -> BaseOperation<Void> {
        ClosureOperation { _ = try requestClosure() }
    }
}
