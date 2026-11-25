import Foundation
import Kingfisher

struct ConfigMirrorImageSource {
    let source: Source
    let options: KingfisherOptionsInfo
}

/// Makes Kingfisher load images the config mirror serves from the mirror first and from the original url
/// when the mirror fails. The cache key stays the original url so that both attempts share one cache entry
/// and the images cached before the mirror existed remain valid.
struct ConfigMirrorImageSourceFactory {
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

    func createSource(for url: URL) -> ConfigMirrorImageSource {
        guard let mirrorURL = urlResolver.mirrorURL(for: url), availability.isAvailable else {
            return ConfigMirrorImageSource(source: url.convertToSource(), options: [])
        }

        let cacheKey = url.absoluteString
        let mirrorResource = Kingfisher.ImageResource(downloadURL: mirrorURL, cacheKey: cacheKey)
        let originalResource = Kingfisher.ImageResource(downloadURL: url, cacheKey: cacheKey)

        let failureObserver = ConfigMirrorImageFailureObserver { error in
            handleMirrorFailure(error, mirrorURL: mirrorURL)
        }

        return ConfigMirrorImageSource(
            source: .network(mirrorResource),
            options: [
                .alternativeSources([.network(originalResource)]),
                .requestModifier(createMirrorRequestModifier(for: mirrorURL)),
                .retryStrategy(failureObserver)
            ]
        )
    }

    func downloadImage(
        with url: URL,
        using downloader: ImageDownloader,
        options: KingfisherOptionsInfo,
        completionHandler: @escaping (Result<ImageLoadingResult, KingfisherError>) -> Void
    ) {
        guard let mirrorURL = urlResolver.mirrorURL(for: url), availability.isAvailable else {
            downloader.downloadImage(with: url, options: options, completionHandler: completionHandler)
            return
        }

        let mirrorOptions = options + [.requestModifier(createMirrorRequestModifier(for: mirrorURL))]

        downloader.downloadImage(with: mirrorURL, options: mirrorOptions) { result in
            switch result {
            case .success:
                completionHandler(result)
            case let .failure(error):
                handleMirrorFailure(error, mirrorURL: mirrorURL)
                downloader.downloadImage(with: url, options: options, completionHandler: completionHandler)
            }
        }
    }
}

private extension ConfigMirrorImageSourceFactory {
    // Kingfisher applies the options to each source it tries, so the modifier itself has to
    // tell the mirror request from the one for the original url that must stay as it is.
    func createMirrorRequestModifier(for mirrorURL: URL) -> AnyModifier {
        AnyModifier { [mirrorTimeout] request in
            guard request.url == mirrorURL else {
                return request
            }

            var mirrorRequest = request
            mirrorRequest.timeoutInterval = min(request.timeoutInterval, mirrorTimeout)

            return mirrorRequest
        }
    }

    func handleMirrorFailure(_ error: KingfisherError, mirrorURL: URL) {
        guard !error.isTaskCancelled else {
            return
        }

        // The availability tells a connection failure by the url session error Kingfisher wraps
        if case let .responseError(reason: .URLSessionError(sessionError)) = error {
            availability.reportFailure(sessionError, for: mirrorURL, logger: logger)
        } else {
            availability.reportFailure(error, for: mirrorURL, logger: logger)
        }
    }
}

/// Kingfisher gives no callback for a source it has given up on in favour of an alternative one,
/// except for asking the retry strategy what to do with the failure. This strategy never retries,
/// it only reports the failure of the first source, which is the mirror.
private struct ConfigMirrorImageFailureObserver: RetryStrategy {
    let failureClosure: (KingfisherError) -> Void

    func retry(context: RetryContext, retryHandler: @escaping (RetryDecision) -> Void) {
        // The context keeps the error of the first failed source and counts the next ones
        if context.retriedCount == 0 {
            failureClosure(context.error)
        }

        retryHandler(.stop)
    }
}
