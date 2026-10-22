import Foundation
import NovaOperationSupport
import Operation_iOS

final class NovaAuthBootstrapOperationFactory {
    private let http: NovaAuthHTTPProtocol
    private let clock: NovaAuthClockProtocol

    init(http: NovaAuthHTTPProtocol, clock: NovaAuthClockProtocol) {
        self.http = http
        self.clock = clock
    }

    func createRegistrationChallengeWrapper(
        origin: NovaAuthOrigin,
        clientID: String,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        createWrapper(
            origin: origin,
            route: .registrationChallenge,
            contentType: NovaAuthWire.contentType,
            body: { try NovaAuthWire.challengeBody(clientID: clientID, purpose: .registration) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeChallenge
        )
    }

    func createTokenChallengeWrapper(
        origin: NovaAuthOrigin,
        clientID: String,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthChallenge> {
        createWrapper(
            origin: origin,
            route: .tokenChallenge,
            contentType: NovaAuthWire.contentType,
            body: { try NovaAuthWire.challengeBody(clientID: clientID, purpose: .token) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeChallenge
        )
    }

    func createRegistrationWrapper(
        _ request: NovaAuthRegistrationRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<Void> {
        createWrapper(
            origin: request.origin,
            route: .registration,
            contentType: request.contentType,
            body: { try NovaAuthWire.registrationBody(request) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeRegistration
        )
    }

    func createTokenWrapper(
        _ request: NovaAuthTokenRequest,
        beforeSend: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<NovaAuthTokenResponse> {
        createWrapper(
            origin: request.origin,
            route: .token,
            contentType: request.contentType,
            body: { try NovaAuthWire.tokenBody(request) },
            beforeSend: beforeSend,
            decode: NovaAuthWire.decodeToken
        )
    }
}

private extension NovaAuthBootstrapOperationFactory {
    // swiftlint:disable:next function_parameter_count
    func createWrapper<T>(
        origin: NovaAuthOrigin,
        route: NovaAuthBootstrapRoute,
        contentType: String,
        body: () throws -> Data,
        beforeSend: @escaping () throws -> Void,
        decode: @escaping (NovaAuthResponse) throws -> T
    ) -> CompoundOperationWrapper<T> {
        do {
            guard let url = URL(string: origin.value + route.path) else { throw NovaAuthError.invalidRequest }
            try NovaAuthValidation.contentType(contentType)
            let bytes = try body()
            var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
            request.httpMethod = HttpMethod.post.rawValue
            request.httpBody = bytes
            request.setValue(contentType, forHTTPHeaderField: HttpHeaderKey.contentType.rawValue)
            request.setValue(String(bytes.count), forHTTPHeaderField: "Content-Length")
            let clock = clock
            return http.createResponseWrapper(for: request, kind: .bootstrap, beforeSend: {
                _ = try clock.now()
                try beforeSend()
            }, decode: decode)
        } catch { return .createWithError(error) }
    }
}
