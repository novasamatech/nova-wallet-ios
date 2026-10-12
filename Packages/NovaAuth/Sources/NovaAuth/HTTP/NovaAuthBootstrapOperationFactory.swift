import Foundation
import Operation_iOS
import NovaOperationSupport

final class NovaAuthBootstrapOperationFactory: NovaAuthBootstrapProtocol {
    private let http: NovaAuthHTTPProtocol
    private let clock: NovaAuthClockProtocol

    init(http: NovaAuthHTTPProtocol, clock: NovaAuthClockProtocol) {
        self.http = http
        self.clock = clock
    }

    func createRegistrationChallengeWrapper(
        origin: NovaAuthOrigin,
        clientID: String,
        beforeSend: @escaping () throws -> Void = {}
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        createWrapper(
            origin: origin,
            path: "/v1/attestation/profile-3/challenges",
            contentType: NovaAuthWire.contentType,
            body: { try NovaAuthWire.challengeBody(clientID: clientID, purpose: .registration) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeChallenge
        )
    }

    func createTokenChallengeWrapper(
        origin: NovaAuthOrigin,
        clientID: String,
        beforeSend: @escaping () throws -> Void = {}
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        createWrapper(
            origin: origin,
            path: "/v1/attestation/profile-3/token-challenges",
            contentType: NovaAuthWire.contentType,
            body: { try NovaAuthWire.challengeBody(clientID: clientID, purpose: .token) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeChallenge
        )
    }

    func createRegistrationWrapper(
        _ request: NovaAuthRegistrationRequest,
        beforeSend: @escaping () throws -> Void = {}
    ) -> CompoundOperationWrapper<Void> {
        createWrapper(
            origin: request.origin,
            path: NovaAuthPurpose.registration.path,
            contentType: request.contentType,
            body: { try NovaAuthWire.registrationBody(request) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeRegistration
        )
    }

    func createTokenWrapper(
        _ request: NovaAuthTokenRequest,
        beforeSend: @escaping () throws -> Void = {}
    ) -> CompoundOperationWrapper<NovaAuthTokenResponse> {
        createWrapper(
            origin: request.origin,
            path: NovaAuthPurpose.token.path,
            contentType: request.contentType,
            body: { try NovaAuthWire.tokenBody(request) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeToken
        )
    }
}

private extension NovaAuthBootstrapOperationFactory {
    // The send fence remains explicit alongside the immutable wire inputs.
    // swiftlint:disable:next function_parameter_count
    func createWrapper<T>(
        origin: NovaAuthOrigin,
        path: String,
        contentType: String,
        body: () throws -> Data,
        beforeSend: @escaping () throws -> Void,
        decode: @escaping (NovaAuthResponse) throws -> T
    ) -> CompoundOperationWrapper<T> {
        do {
            guard let url = URL(string: origin.value + path) else { throw NovaAuthError.invalidRequest }
            try NovaAuthValidation.contentType(contentType)
            let bytes = try body()
            var request = URLRequest(
                url: url,
                cachePolicy: .reloadIgnoringLocalCacheData,
                timeoutInterval: path == NovaAuthPurpose.registration.path ? 100 : 20
            )
            request.httpMethod = "POST"
            request.httpBody = bytes
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.setValue(String(bytes.count), forHTTPHeaderField: "Content-Length")
            let clock = clock
            let wrapper = http.createResponseWrapper(for: request, kind: .bootstrap, beforeSend: {
                _ = try clock.now()
                try beforeSend()
            })
            let operation = ClosureOperation<T> {
                let response = try wrapper.targetOperation.extractNoCancellableResultData()
                guard response.response.url == url else { throw NovaAuthError.invalidResponse }
                return try decode(response)
            }
            operation.addDependency(wrapper.targetOperation)
            return wrapper.insertingTail(operation: operation)
        } catch { return .createWithError(error) }
    }
}
