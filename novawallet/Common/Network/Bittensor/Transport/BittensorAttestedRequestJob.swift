import Foundation
import Operation_iOS
import NovaAppAttest

struct BittensorAttestedJobEnvironment {
    let executor: BittensorAttestedRequestExecutor
    let session: URLSession
    let operationQueue: OperationQueue
    let logger: LoggerProtocol
}

final class BittensorAttestedRequestJob {
    typealias Completion = (Result<BittensorApiRawResponse, Error>) -> Void

    struct Attempt {
        let deadline: TimeInterval
        let isRetry: Bool
        let replacedClientId: String?
        let replacedRequestId: String?
    }

    private let request: BittensorApiRequest
    private let contextOperation: BaseOperation<BittensorAttestationContext>
    private let environment: BittensorAttestedJobEnvironment
    private let mutex = NSLock()

    private var prepared: BittensorAttestedPreparedRequest?
    private var enqueuedAt: TimeInterval = 0
    private var completion: Completion?
    private var isCancelled = false
    private var isFinished = false

    init(
        request: BittensorApiRequest,
        contextOperation: BaseOperation<BittensorAttestationContext>,
        environment: BittensorAttestedJobEnvironment
    ) {
        self.request = request
        self.contextOperation = contextOperation
        self.environment = environment
    }
}

extension BittensorAttestedRequestJob: Longrunable {
    typealias ResultType = BittensorApiRawResponse

    func start(with completionClosure: @escaping Completion) {
        let preparedRequest: BittensorAttestedPreparedRequest

        do {
            let context = try contextOperation.extractNoCancellableResultData()
            preparedRequest = try BittensorAttestedRequestBuilder.prepare(request, context: context)
        } catch {
            completionClosure(.failure(error))

            return
        }

        mutex.lock()

        guard !isCancelled else {
            mutex.unlock()

            return
        }

        prepared = preparedRequest
        enqueuedAt = environment.executor.now()
        completion = completionClosure

        mutex.unlock()

        environment.executor.submit(self)
    }

    func cancel() {
        mutex.lock()

        isCancelled = true
        completion = nil

        mutex.unlock()

        environment.executor.cancel(self)
    }
}

extension BittensorAttestedRequestJob: BittensorAttestedExecutorJob {
    func run() {
        mutex.lock()

        let attempt = Attempt(
            deadline: enqueuedAt + BittensorSignBudget.maxWait,
            isRetry: false,
            replacedClientId: nil,
            replacedRequestId: nil
        )

        mutex.unlock()

        requestAdmission(for: attempt)
    }
}

private extension BittensorAttestedRequestJob {
    var isStopped: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return isCancelled
    }

    var preparedRequest: BittensorAttestedPreparedRequest? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return prepared
    }

    var routeDescription: String {
        "Bittensor \(request.method.rawValue) \(request.pathTemplate)"
    }

    func requestAdmission(for attempt: Attempt) {
        guard !isStopped else {
            finish(with: .failure(BaseOperationError.parentOperationCancelled))

            return
        }

        environment.executor.admitSignAttempt(for: self, deadline: attempt.deadline) { [weak self] admission in
            switch admission {
            case .granted:
                self?.sign(for: attempt)
            case let .refused(error):
                self?.fail(with: error, during: attempt)
            case .cancelled:
                self?.finish(with: .failure(BaseOperationError.parentOperationCancelled))
            }
        }
    }

    func sign(for attempt: Attempt) {
        guard let prepared = preparedRequest else {
            finish(with: .failure(BittensorApiError.configuration))

            return
        }

        let signedBody = prepared.body ?? Data()

        let headersWrapper = prepared.context.provider.createSignedHeadersWrapper(target: prepared.target) {
            signedBody
        }

        execute(
            wrapper: headersWrapper,
            inOperationQueue: environment.operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            switch result {
            case let .success(headers):
                self?.send(prepared: prepared, headers: headers, attempt: attempt)
            case let .failure(error):
                self?.handleSigningFailure(error, attempt: attempt)
            }
        }
    }

    func send(
        prepared: BittensorAttestedPreparedRequest,
        headers: [AttestationHeaderKey: String]?,
        attempt: Attempt
    ) {
        guard let headers, let signedClientId = headers[.clientId] else {
            fail(with: .attestationFailure(requestId: nil), during: attempt)

            return
        }

        if let replacedClientId = attempt.replacedClientId, replacedClientId == signedClientId {
            environment.logger.warning("\(routeDescription) kept the refused client id, not retrying")

            finish(with: .failure(BittensorApiError.attestationFailure(requestId: attempt.replacedRequestId)))

            return
        }

        guard !isStopped else {
            finish(with: .failure(BaseOperationError.parentOperationCancelled))

            return
        }

        let sendOperation = BittensorAttestedRequestBuilder.createSendOperation(
            for: prepared,
            headers: headers,
            session: environment.session
        )

        execute(
            operation: sendOperation,
            inOperationQueue: environment.operationQueue,
            runningCallbackIn: nil
        ) { [weak self] result in
            switch result {
            case let .success(response):
                self?.handle(response: response, prepared: prepared, signedClientId: signedClientId, attempt: attempt)
            case let .failure(error):
                self?.handleTransportFailure(error)
            }
        }
    }

    func handle(
        response: BittensorAttestedResponse,
        prepared: BittensorAttestedPreparedRequest,
        signedClientId: String,
        attempt: Attempt
    ) {
        let grade = BittensorAttestedResponseGrader.grade(
            response,
            isRecommendationsRoute: prepared.isRecommendationsRoute
        )

        log(response: response, grade: grade)

        switch grade {
        case let .success(rawResponse):
            finish(with: .success(rawResponse))
        case let .retryWithFreshProof(requestId):
            retryOrFail(after: attempt, requestId: requestId, replacedClientId: nil)
        case let .unknownClient(requestId):
            prepared.context.provider.markUnattested(ifCurrentClientId: signedClientId)

            retryOrFail(after: attempt, requestId: requestId, replacedClientId: signedClientId)
        case let .failure(error):
            if case .attestationRejected = error {
                environment.executor.latchRejection()
            }

            finish(with: .failure(error))
        }
    }

    func retryOrFail(after attempt: Attempt, requestId: String?, replacedClientId: String?) {
        guard !attempt.isRetry else {
            finish(with: .failure(BittensorApiError.attestationFailure(requestId: requestId)))

            return
        }

        let retryAttempt = Attempt(
            deadline: environment.executor.now() + BittensorSignBudget.maxWait,
            isRetry: true,
            replacedClientId: replacedClientId,
            replacedRequestId: requestId
        )

        requestAdmission(for: retryAttempt)
    }

    func handleSigningFailure(_ error: Error, attempt: Attempt) {
        let apiError = BittensorAttestedResponseGrader.mapSigningError(error)

        if BittensorAttestedResponseGrader.isChallengeRateLimit(error) {
            environment.executor.startChallengeCooldown()
        }

        if case .attestationRejected = apiError {
            environment.executor.latchRejection()
        }

        environment.logger.warning("\(routeDescription) not signed: \(apiError)")

        fail(with: apiError, during: attempt)
    }

    func fail(with error: BittensorApiError, during attempt: Attempt) {
        let carriedError = BittensorAttestedResponseGrader.carryingRequestId(attempt.replacedRequestId, in: error)

        finish(with: .failure(carriedError))
    }

    func handleTransportFailure(_ error: Error) {
        environment.logger.warning("\(routeDescription) transport failure: \(error)")

        finish(with: .failure(BittensorApiError.transport(error)))
    }

    func log(response: BittensorAttestedResponse, grade: BittensorAttestedGrade) {
        let code = AttestationHTTP.rawErrorCode(from: response.body) ?? "-"
        let requestId = response.requestId ?? "-"
        let message = "\(routeDescription) -> \(response.statusCode) code \(code) request id \(requestId)"

        switch grade {
        case .success:
            environment.logger.debug(message)
        case .retryWithFreshProof, .unknownClient, .failure:
            environment.logger.warning(message)
        }
    }

    func finish(with result: Result<BittensorApiRawResponse, Error>) {
        mutex.lock()

        guard !isFinished else {
            mutex.unlock()

            return
        }

        isFinished = true

        let completionClosure = completion
        completion = nil

        mutex.unlock()

        environment.executor.finish(self)

        completionClosure?(result)
    }
}
