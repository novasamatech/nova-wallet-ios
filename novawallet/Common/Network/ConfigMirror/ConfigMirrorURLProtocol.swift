import Foundation
import Kingfisher
import Operation_iOS

/// Reads the files of the config mirror's origin from the mirror first and from the original url when
/// the mirror attempt fails. The caller keeps requesting the original url and receives a response for it,
/// so nothing that is keyed by the url (caches, stored files) knows about the mirror.
final class ConfigMirrorURLProtocol: URLProtocol {
    struct Dependencies {
        var urlResolver: ConfigMirrorURLResolverProtocol = ConfigMirrorURLResolver(
            applicationConfig: ApplicationConfig.shared
        )
        var availability: ConfigMirrorAvailabilityProtocol = ConfigMirrorAvailability()
        var loader: ConfigMirrorLoaderProtocol = ConfigMirrorLoader()
        var mirrorTimeout: TimeInterval = ConfigMirrorConstants.attemptTimeout
        var logger: LoggerProtocol = Logger.shared
    }

    /// The system creates the instances itself, so the dependencies can't be passed to them.
    /// Must be set before the class is registered.
    static var dependencies = Dependencies()

    /// Makes the requests of `URLSession.shared` and of the image downloader go through the mirror
    static func register(for imageDownloader: ImageDownloader = KingfisherManager.shared.downloader) {
        URLProtocol.registerClass(ConfigMirrorURLProtocol.self)

        // the downloader recreates its session when the configuration is assigned
        let configuration = imageDownloader.sessionConfiguration
        configuration.protocolClasses = [ConfigMirrorURLProtocol.self] + (configuration.protocolClasses ?? [])
        imageDownloader.sessionConfiguration = configuration
    }

    private let dependencies = ConfigMirrorURLProtocol.dependencies

    // The state below is touched on the client thread only
    private var clientThread: Thread?
    private var clientModes: [String] = []
    private var loadTask: ConfigMirrorLoadTaskProtocol?
    private var isStopped = false
    private var isMirrorAccepted = false
    private var mirrorResponse: URLResponse?
    private var mirrorData = Data()

    override static func canInit(with request: URLRequest) -> Bool {
        guard
            let url = request.url,
            request.httpMethod?.caseInsensitiveCompare(HttpMethod.get.rawValue) == .orderedSame,
            property(forKey: Constants.handledKey, in: request) == nil else {
            return false
        }

        return dependencies.urlResolver.mirrorURL(for: url) != nil
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let currentMode = RunLoop.current.currentMode

        clientThread = Thread.current
        clientModes = [RunLoop.Mode.default, currentMode].compactMap { $0?.rawValue }

        guard
            dependencies.availability.isAvailable,
            let mirrorURL = request.url.flatMap({ dependencies.urlResolver.mirrorURL(for: $0) }),
            let mirrorRequest = createInnerRequest(for: mirrorURL) else {
            loadOriginal()
            return
        }

        loadTask = dependencies.loader.load(mirrorRequest) { [weak self] event in
            self?.performOnClientThread { self?.handleMirror(event, mirrorURL: mirrorURL) }
        }
    }

    override func stopLoading() {
        isStopped = true
        loadTask?.cancel()
        loadTask = nil
    }
}

// MARK: Private

private extension ConfigMirrorURLProtocol {
    enum Constants {
        static let handledKey = "io.novawallet.configMirror.handled"
        static let maxRequestTimeoutShare: Double = 0.5
        static let successStatusCode = 200
        static let jsonExtension = "json"
        static let httpVersion = "HTTP/1.1"
    }

    /// A copy of the caller's request marked not to be picked up by this class again.
    /// For the mirror it gets a shorter timeout: the mirror stands in front of the request the caller
    /// has set the timeout for, so it may take no more than a part of it before the original url is read.
    func createInnerRequest(for mirrorURL: URL?) -> URLRequest? {
        guard let innerRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return nil
        }

        URLProtocol.setProperty(true, forKey: Constants.handledKey, in: innerRequest)

        if let mirrorURL {
            innerRequest.url = mirrorURL
            innerRequest.timeoutInterval = min(
                dependencies.mirrorTimeout,
                request.timeoutInterval * Constants.maxRequestTimeoutShare
            )
        }

        return innerRequest as URLRequest
    }

    func handleMirror(_ event: ConfigMirrorLoadEvent, mirrorURL: URL) {
        guard !isStopped else {
            return
        }

        switch event {
        case let .response(response):
            mirrorResponse = response
        case let .data(data):
            mirrorData.append(data)

            // A json has to be complete to be checked. Anything else is passed on as it arrives
            // for the caller's timeout to keep measuring silence and not the whole download.
            if isMirrorAccepted || !isJson(mirrorURL), hasSuccessStatus(mirrorResponse) {
                passMirrorDataToClient()
            }
        case let .completed(error):
            let failure = error ?? validateMirrorAnswer(from: mirrorURL)

            if let failure {
                reportMirrorFailure(failure, mirrorURL: mirrorURL)
            }

            // a part of the body that the caller already has can't be taken back to read the original url
            if failure != nil, !isMirrorAccepted {
                mirrorResponse = nil
                mirrorData = Data()

                loadOriginal()
            } else {
                passMirrorDataToClient()
                complete(with: error)
            }
        }
    }

    func isJson(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == Constants.jsonExtension
    }

    func hasSuccessStatus(_ response: URLResponse?) -> Bool {
        (response as? HTTPURLResponse)?.statusCode == Constants.successStatusCode
    }

    /// Callers that receive raw data decode it when the request is over and it is too late to fall back,
    /// so an answer of the mirror counts only if its body is usable.
    func validateMirrorAnswer(from mirrorURL: URL) -> Error? {
        guard hasSuccessStatus(mirrorResponse) else {
            return ConfigMirrorFailure.unexpectedStatus((mirrorResponse as? HTTPURLResponse)?.statusCode)
        }

        guard isMirrorAccepted || !mirrorData.isEmpty else {
            return ConfigMirrorFailure.emptyBody
        }

        guard isJson(mirrorURL), (try? JSONSerialization.jsonObject(with: mirrorData)) == nil else {
            return nil
        }

        return ConfigMirrorFailure.malformedJson
    }

    func passMirrorDataToClient() {
        if !isMirrorAccepted, let mirrorResponse {
            isMirrorAccepted = true

            // the session that performs the inner request has already cached it under the mirror url
            client?.urlProtocol(self, didReceive: createResponse(from: mirrorResponse), cacheStoragePolicy: .notAllowed)
        }

        if !mirrorData.isEmpty {
            client?.urlProtocol(self, didLoad: mirrorData)
            mirrorData = Data()
        }
    }

    /// The caller has asked for the original url, so the response is made for it
    func createResponse(from mirrorResponse: URLResponse) -> URLResponse {
        guard let url = request.url, let httpResponse = mirrorResponse as? HTTPURLResponse else {
            return mirrorResponse
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: httpResponse.statusCode,
            httpVersion: Constants.httpVersion,
            headerFields: httpResponse.allHeaderFields as? [String: String]
        )

        return response ?? mirrorResponse
    }

    func reportMirrorFailure(_ failure: Error, mirrorURL: URL) {
        let logger = dependencies.logger

        logger.warning("Config mirror failed for \(mirrorURL.path): \(failure)")

        if dependencies.availability.registerFailure(failure) {
            logger.warning("Config mirror is unavailable, skipping it until the cool-down ends")
        }
    }

    func loadOriginal() {
        guard let originalRequest = createInnerRequest(for: nil) else {
            complete(with: NetworkBaseError.invalidUrl)
            return
        }

        loadTask = dependencies.loader.load(originalRequest) { [weak self] event in
            self?.performOnClientThread { self?.handleOriginal(event) }
        }
    }

    func handleOriginal(_ event: ConfigMirrorLoadEvent) {
        guard !isStopped else {
            return
        }

        switch event {
        case let .response(response):
            // the session that performs the inner request has already cached it under the same url
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        case let .data(data):
            client?.urlProtocol(self, didLoad: data)
        case let .completed(error):
            complete(with: error)
        }
    }

    func complete(with error: Error?) {
        loadTask = nil

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    /// The loader reports on a queue of its own while the client expects to be called on the thread
    /// the loading was started on
    func performOnClientThread(_ closure: @escaping () -> Void) {
        guard let clientThread, Thread.current != clientThread else {
            closure()
            return
        }

        perform(
            #selector(execute(_:)),
            on: clientThread,
            with: ClosureBox(closure: closure),
            waitUntilDone: false,
            modes: clientModes
        )
    }

    @objc func execute(_ box: ClosureBox) {
        box.closure()
    }
}

enum ConfigMirrorFailure: Error {
    case unexpectedStatus(Int?)
    case emptyBody
    case malformedJson
}

private final class ClosureBox: NSObject {
    let closure: () -> Void

    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
}
