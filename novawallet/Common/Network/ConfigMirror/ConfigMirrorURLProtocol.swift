import Foundation
import Operation_iOS

/// Reads the files of the config mirror's origin from the mirror first and from the original url when
/// the mirror attempt fails. The caller keeps requesting the original url and receives a response for it,
/// so nothing that is keyed by the url (caches, stored files) knows about the mirror.
///
/// The answer of the mirror is collected in full and checked before the caller gets any of it:
/// whatever goes wrong with the mirror, the original url can still be read.
final class ConfigMirrorURLProtocol: URLProtocol {
    struct Dependencies {
        let urlResolver: ConfigMirrorURLResolverProtocol
        let availability: ConfigMirrorAvailabilityProtocol
        let loader: ConfigMirrorLoaderProtocol
        let logger: LoggerProtocol
        var answerValidator: ConfigMirrorAnswerValidating = ConfigMirrorAnswerValidator()
        var attemptDeadline: TimeInterval = ConfigMirrorConstants.attemptDeadline
        var schedulerClosure: (SchedulerDelegate) -> SchedulerProtocol = { Scheduler(with: $0) }
    }

    private static let dependenciesMutex = NSLock()
    private static var registeredDependencies: Dependencies?

    /// The system creates the instances itself, so the dependencies can't be passed to them
    private(set) static var dependencies: Dependencies? {
        get {
            dependenciesMutex.lock()
            defer { dependenciesMutex.unlock() }

            return registeredDependencies
        }
        set {
            dependenciesMutex.lock()
            registeredDependencies = newValue
            dependenciesMutex.unlock()
        }
    }

    /// Makes the requests of `URLSession.shared` go through the mirror. Any other session joins
    /// by having the class in the `protocolClasses` of its configuration.
    static func register(dependencies: Dependencies) {
        self.dependencies = dependencies

        URLProtocol.registerClass(ConfigMirrorURLProtocol.self)
    }

    static func unregister() {
        URLProtocol.unregisterClass(ConfigMirrorURLProtocol.self)

        dependencies = nil
    }

    private let dependencies = ConfigMirrorURLProtocol.dependencies

    // The state below is touched on the client thread only
    private var clientThread: Thread?
    private var clientModes: [String] = []
    private var stage = Stage.idle
    private var loadTask: ConfigMirrorLoadTaskProtocol?
    private var deadlineScheduler: SchedulerProtocol?
    private var mirrorResponse: URLResponse?
    private var mirrorData = Data()
    private var isMirrorAnswerFromLocalCache = false

    override static func canInit(with request: URLRequest) -> Bool {
        guard
            let dependencies,
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

        // the availability goes last: an attempt it has let in must be started for it to be finished
        guard
            let dependencies,
            let mirrorURL = request.url.flatMap({ dependencies.urlResolver.mirrorURL(for: $0) }),
            let mirrorRequest = createInnerRequest(for: mirrorURL),
            let attemptKind = dependencies.availability.beginAttempt() else {
            loadOriginal()
            return
        }

        stage = .mirror(MirrorAttempt(url: mirrorURL, kind: attemptKind))

        // the same time bounds the silence of the mirror request and the attempt as a whole
        let scheduler = dependencies.schedulerClosure(self)
        scheduler.notifyAfter(mirrorRequest.timeoutInterval)
        deadlineScheduler = scheduler

        let validator = dependencies.answerValidator
        let rules = ConfigMirrorLoadRules.mirror { response, data in
            validator.validate(response: response, data: data, mirrorURL: mirrorURL) == nil
        }

        loadTask = dependencies.loader.load(mirrorRequest, rules: rules) { [weak self] event in
            self?.performOnClientThread { self?.handleMirror(event) }
        }
    }

    override func stopLoading() {
        if case let .mirror(attempt) = stage {
            // the caller has left, which says nothing about the mirror
            reportMirrorAttempt(attempt, verdict: .unknown)
        }

        stage = .finished
        loadTask?.cancel()
        loadTask = nil
    }
}

extension ConfigMirrorURLProtocol: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        performOnClientThread { [weak self] in
            self?.handleMirrorDeadline(of: scheduler)
        }
    }
}

// MARK: Private

private extension ConfigMirrorURLProtocol {
    struct MirrorAttempt {
        let url: URL
        let kind: ConfigMirrorAttemptKind
    }

    enum Stage {
        case idle
        case mirror(MirrorAttempt)
        case original
        case finished
    }

    enum Constants {
        static let handledKey = "io.novawallet.configMirror.handled"
        static let httpVersion = "HTTP/1.1"
    }

    /// A copy of the caller's request marked not to be picked up by this class again.
    /// For the mirror it gets the time of the whole attempt as its timeout: the mirror stands in front
    /// of the request the caller has set the timeout for, so it may take no more than a part of it
    /// before the original url is read.
    func createInnerRequest(for mirrorURL: URL?) -> URLRequest? {
        guard let innerRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return nil
        }

        URLProtocol.setProperty(true, forKey: Constants.handledKey, in: innerRequest)

        if let mirrorURL, let dependencies {
            innerRequest.url = mirrorURL
            innerRequest.timeoutInterval = min(
                dependencies.attemptDeadline,
                request.timeoutInterval * ConfigMirrorConstants.maxRequestTimeoutShare
            )
        }

        return innerRequest as URLRequest
    }

    func handleMirror(_ event: ConfigMirrorLoadEvent) {
        // an attempt that is over, by the deadline too, may still have events on their way
        guard case let .mirror(attempt) = stage, let dependencies else {
            return
        }

        switch event {
        case let .response(response):
            mirrorResponse = response
        case let .data(data):
            mirrorData.append(data)
        case .servedFromLocalCache:
            isMirrorAnswerFromLocalCache = true
        case let .completed(error):
            let failure = error.map { ConfigMirrorFailure.transport($0) } ?? dependencies.answerValidator.validate(
                response: mirrorResponse,
                data: mirrorData,
                mirrorURL: attempt.url
            )

            completeMirrorAttempt(attempt, failure: failure)
        }
    }

    /// The timeout of the mirror request measures silence only, so a body that keeps dripping would
    /// outlast it and the caller's own timeout would end the request with nothing read
    func handleMirrorDeadline(of scheduler: SchedulerProtocol) {
        guard case let .mirror(attempt) = stage, scheduler === deadlineScheduler else {
            return
        }

        loadTask?.cancel()
        loadTask = nil

        completeMirrorAttempt(attempt, failure: .deadlineExceeded)
    }

    func completeMirrorAttempt(_ attempt: MirrorAttempt, failure: ConfigMirrorFailure?) {
        if let failure {
            dependencies?.logger.warning("Config mirror failed for \(attempt.url.path): \(failure)")
        }

        // an answer of the http cache is not an answer of the mirror
        let verdict = isMirrorAnswerFromLocalCache ? ConfigMirrorAttemptVerdict.unknown : failure?.verdict ?? .reachable

        reportMirrorAttempt(attempt, verdict: verdict)

        if failure != nil {
            mirrorResponse = nil
            mirrorData = Data()

            loadOriginal()
        } else {
            passMirrorAnswerToClient()
            complete(with: nil)
        }
    }

    func reportMirrorAttempt(_ attempt: MirrorAttempt, verdict: ConfigMirrorAttemptVerdict) {
        deadlineScheduler?.cancel()
        deadlineScheduler = nil

        guard let dependencies else {
            return
        }

        if let pause = dependencies.availability.endAttempt(attempt.kind, verdict: verdict) {
            dependencies.logger.warning("Config mirror is unavailable, skipping it for \(Int(pause)) s")
        }
    }

    func passMirrorAnswerToClient() {
        guard let mirrorResponse else {
            return
        }

        // the session that performs the inner request has already cached it under the mirror url
        client?.urlProtocol(self, didReceive: createResponse(from: mirrorResponse), cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: mirrorData)

        self.mirrorResponse = nil
        mirrorData = Data()
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

    func loadOriginal() {
        guard let dependencies, let originalRequest = createInnerRequest(for: nil) else {
            complete(with: NetworkBaseError.invalidUrl)
            return
        }

        stage = .original

        loadTask = dependencies.loader.load(originalRequest, rules: .original) { [weak self] event in
            self?.performOnClientThread { self?.handleOriginal(event) }
        }
    }

    func handleOriginal(_ event: ConfigMirrorLoadEvent) {
        guard case .original = stage else {
            return
        }

        switch event {
        case let .response(response):
            // the session that performs the inner request has already cached it under the same url
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        case let .data(data):
            client?.urlProtocol(self, didLoad: data)
        case .servedFromLocalCache:
            break
        case let .completed(error):
            complete(with: error)
        }
    }

    func complete(with error: Error?) {
        stage = .finished
        loadTask = nil

        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    /// The loader and the deadline report on queues of their own while the client expects to be called
    /// on the thread the loading was started on
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

private final class ClosureBox: NSObject {
    let closure: () -> Void

    init(closure: @escaping () -> Void) {
        self.closure = closure
    }
}
