import Foundation
import Operation_iOS

typealias ConfigMirrorRequestFactoryClosure = (_ url: URL, _ timeout: TimeInterval?) -> NetworkRequestFactoryProtocol

protocol ConfigMirrorFetchFactoryProtocol {
    /// The request factory closure is called before the method returns: for the original url
    /// and, when the mirror is going to be tried, for the mirror one.
    func createFetchOperation<T>(
        from url: URL,
        timeout: TimeInterval?,
        resultFactory: AnyNetworkResultFactory<T>,
        requestFactoryClosure: ConfigMirrorRequestFactoryClosure
    ) -> BaseOperation<T>
}

enum ConfigMirrorFetchError: Error {
    case emptyBody
    case malformedJson(Error)
}

/// Fetches files the config mirror serves from the mirror first and reads the original url
/// when that attempt fails for any reason. Other urls are fetched as is.
final class ConfigMirrorFetchOperationFactory {
    private let urlResolver: ConfigMirrorURLResolverProtocol
    private let availability: ConfigMirrorAvailabilityProtocol
    private let mirrorTimeout: TimeInterval
    private let logger: LoggerProtocol

    init(
        urlResolver: ConfigMirrorURLResolverProtocol = ConfigMirrorURLResolver.shared,
        availability: ConfigMirrorAvailabilityProtocol = ConfigMirrorAvailability.shared,
        mirrorTimeout: TimeInterval = ConfigMirrorConstants.attemptTimeout,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.urlResolver = urlResolver
        self.availability = availability
        self.mirrorTimeout = mirrorTimeout
        self.logger = logger
    }
}

extension ConfigMirrorFetchOperationFactory: ConfigMirrorFetchFactoryProtocol {
    func createFetchOperation<T>(
        from url: URL,
        timeout: TimeInterval?,
        resultFactory: AnyNetworkResultFactory<T>,
        requestFactoryClosure: ConfigMirrorRequestFactoryClosure
    ) -> BaseOperation<T> {
        let originalRequestFactory = requestFactoryClosure(url, timeout)

        guard let mirrorURL = urlResolver.mirrorURL(for: url), availability.isAvailable else {
            return NetworkOperation(requestFactory: originalRequestFactory, resultFactory: resultFactory)
        }

        let mirrorRequestFactory = requestFactoryClosure(mirrorURL, createMirrorTimeout(for: timeout))
        let mirrorResultFactory = createMirrorResultFactory(for: mirrorURL, resultFactory: resultFactory)

        let longrun = OperationFallbackLongrun<T>(
            primaryClosure: {
                NetworkOperation(requestFactory: mirrorRequestFactory, resultFactory: mirrorResultFactory)
            },
            fallbackClosure: {
                NetworkOperation(requestFactory: originalRequestFactory, resultFactory: resultFactory)
            },
            onPrimaryFailure: { [availability, logger] error in
                availability.reportFailure(error, for: mirrorURL, logger: logger)
            }
        )

        return LongrunOperation(longrun: AnyLongrun(longrun: longrun))
    }
}

private extension ConfigMirrorFetchOperationFactory {
    enum Constants {
        static let callerTimeoutShare: TimeInterval = 2
        static let jsonExtension = "json"
    }

    // The mirror stands in front of the request the caller has set the timeout for,
    // so it may take no more than a part of that timeout before the original url is read
    func createMirrorTimeout(for timeout: TimeInterval?) -> TimeInterval {
        guard let timeout else {
            return mirrorTimeout
        }

        return min(mirrorTimeout, timeout / Constants.callerTimeoutShare)
    }

    // Callers that receive raw data decode it after the operation completes, when it is too late to fall back.
    // So an answer of the mirror counts only if its body is usable.
    func createMirrorResultFactory<T>(
        for mirrorURL: URL,
        resultFactory: AnyNetworkResultFactory<T>
    ) -> AnyNetworkResultFactory<T> {
        let isJson = mirrorURL.pathExtension.lowercased() == Constants.jsonExtension

        return AnyNetworkResultFactory<T>(block: { data, response, error in
            if let error {
                return .failure(error)
            }

            if let statusError = NetworkOperationHelper.createError(from: response) {
                return .failure(statusError)
            }

            guard let data, !data.isEmpty else {
                return .failure(ConfigMirrorFetchError.emptyBody)
            }

            if isJson {
                do {
                    _ = try JSONSerialization.jsonObject(with: data)
                } catch {
                    return .failure(ConfigMirrorFetchError.malformedJson(error))
                }
            }

            return resultFactory.createResult(data: data, response: response, error: nil)
        })
    }
}
