import Foundation
import Operation_iOS

/// Fetches files the config mirror serves from the mirror first and reads the original url
/// when that attempt fails for any reason. Other urls are fetched as is.
final class ConfigMirrorFetchOperationFactory {
    typealias RequestFactoryClosure = (_ url: URL, _ timeout: TimeInterval?) -> NetworkRequestFactoryProtocol

    private let urlResolver: ConfigMirrorURLResolverProtocol
    private let mirrorTimeout: TimeInterval

    init(
        urlResolver: ConfigMirrorURLResolverProtocol = ConfigMirrorURLResolver.shared,
        mirrorTimeout: TimeInterval = Constants.mirrorTimeout
    ) {
        self.urlResolver = urlResolver
        self.mirrorTimeout = mirrorTimeout
    }

    func createFetchOperation<T>(
        from url: URL,
        timeout: TimeInterval?,
        resultFactory: AnyNetworkResultFactory<T>,
        requestFactoryClosure: @escaping RequestFactoryClosure
    ) -> BaseOperation<T> {
        guard let mirrorURL = urlResolver.mirrorURL(for: url) else {
            return NetworkOperation(
                requestFactory: requestFactoryClosure(url, timeout),
                resultFactory: resultFactory
            )
        }

        // An unreachable mirror must not cost as much as the request it stands in front of
        let mirrorAttemptTimeout = min(mirrorTimeout, timeout ?? mirrorTimeout)

        let longrun = OperationFallbackLongrun<T>(
            primaryClosure: {
                NetworkOperation(
                    requestFactory: requestFactoryClosure(mirrorURL, mirrorAttemptTimeout),
                    resultFactory: resultFactory
                )
            },
            fallbackClosure: {
                NetworkOperation(
                    requestFactory: requestFactoryClosure(url, timeout),
                    resultFactory: resultFactory
                )
            }
        )

        return LongrunOperation(longrun: AnyLongrun(longrun: longrun))
    }
}

extension ConfigMirrorFetchOperationFactory {
    enum Constants {
        static let mirrorTimeout: TimeInterval = 10
    }
}
