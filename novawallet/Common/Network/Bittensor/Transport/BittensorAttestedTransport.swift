import Foundation
import Operation_iOS
import NovaAppAttest

final class BittensorAttestedTransport {
    private let holder: BittensorAttestationHolderProtocol
    private let exchangeGate: BackendAttestationExchangeGate
    private let session: URLSession
    private let operationQueue: OperationQueue
    private let timeProvider: () -> TimeInterval
    private let logger: LoggerProtocol
    private let mutex = NSLock()

    private var isRejectionLatched = false
    private var cooldownEnd: TimeInterval?

    init(
        holder: BittensorAttestationHolderProtocol,
        exchangeGate: BackendAttestationExchangeGate,
        session: URLSession = AttestationHTTP.session,
        operationQueue: OperationQueue,
        timeProvider: @escaping () -> TimeInterval = BittensorMonotonicClock.now,
        logger: LoggerProtocol
    ) {
        self.holder = holder
        self.exchangeGate = exchangeGate
        self.session = session
        self.operationQueue = operationQueue
        self.timeProvider = timeProvider
        self.logger = logger
    }
}

extension BittensorAttestedTransport: BittensorApiTransportProtocol {
    func createResponseWrapper(
        for request: BittensorApiRequest
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        let endpointWrapper = holder.createEndpointWrapper()

        weak var exchangeOperation: BaseOperation<BittensorApiRawResponse>?

        let exchangeWrapper = exchangeGate.createExclusiveWrapper { [self] in
            let endpoint = try endpointWrapper.targetOperation.extractNoCancellableResultData()
            let prepared = try BittensorAttestedRequestBuilder.prepare(request, endpoint: endpoint)

            try checkAdmission()

            return createExchangeWrapper(for: prepared) {
                exchangeOperation?.isCancelled ?? true
            }
        }

        exchangeOperation = exchangeWrapper.targetOperation

        exchangeWrapper.targetOperation.configurationBlock = {
            if case let .failure(error) = endpointWrapper.targetOperation.result {
                exchangeOperation?.result = .failure(error)
            }
        }

        exchangeWrapper.addDependency(wrapper: endpointWrapper)

        return exchangeWrapper.insertingHead(operations: endpointWrapper.allOperations)
    }
}

extension BittensorAttestedTransport {
    static let shared = BittensorAttestedTransport(
        holder: BittensorAttestationHolder(
            attestationHolder: BackendAttestationHolder.shared,
            appAttest: AppAttestService(),
            appIdentity: ApplicationConfig.shared.appAttestAppIdentity,
            isUnitTesting: ProcessInfo.processInfo.arguments.contains("-UNITTEST")
        ),
        exchangeGate: BackendAttestationHolder.shared.exchangeGate,
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )
}

private extension BittensorAttestedTransport {
    enum Constants {
        static let challengeCooldown: TimeInterval = 60
    }

    struct RefusedAttempt {
        let requestId: String?
        let clientId: String?
    }

    enum AttemptOutcome {
        case response(BittensorApiRawResponse)
        case retry(RefusedAttempt)
    }

    func checkAdmission() throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !isRejectionLatched else {
            throw BittensorApiError.attestationRejected(requestId: nil)
        }

        if let cooldownEnd, timeProvider() < cooldownEnd {
            throw BittensorApiError.rateLimited(requestId: nil)
        }
    }

    func latchRejection() {
        mutex.lock()
        isRejectionLatched = true
        mutex.unlock()
    }

    func startChallengeCooldown() {
        mutex.lock()
        cooldownEnd = timeProvider() + Constants.challengeCooldown
        mutex.unlock()
    }

    func createExchangeWrapper(
        for prepared: BittensorAttestedPreparedRequest,
        isCancelled: @escaping () -> Bool
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        let attemptWrapper = createAttemptWrapper(for: prepared, refused: nil)

        let responseWrapper = OperationCombiningService<BittensorApiRawResponse>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) { [self] in
            switch try attemptWrapper.targetOperation.extractNoCancellableResultData() {
            case let .response(response):
                return .createWithResult(response)
            case let .retry(refused):
                guard !isCancelled() else {
                    throw BaseOperationError.parentOperationCancelled
                }

                return createRetryWrapper(for: prepared, refused: refused)
            }
        }

        responseWrapper.addDependency(wrapper: attemptWrapper)

        return responseWrapper.insertingHead(operations: attemptWrapper.allOperations)
    }

    func createRetryWrapper(
        for prepared: BittensorAttestedPreparedRequest,
        refused: RefusedAttempt
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        let attemptWrapper = createAttemptWrapper(for: prepared, refused: refused)

        let responseOperation = ClosureOperation<BittensorApiRawResponse> {
            switch try attemptWrapper.targetOperation.extractNoCancellableResultData() {
            case let .response(response):
                return response
            case let .retry(refusedAgain):
                throw BittensorApiError.attestationFailure(requestId: refusedAgain.requestId)
            }
        }

        responseOperation.addDependency(attemptWrapper.targetOperation)

        return attemptWrapper.insertingTail(operation: responseOperation)
    }

    func createAttemptWrapper(
        for prepared: BittensorAttestedPreparedRequest,
        refused: RefusedAttempt?
    ) -> CompoundOperationWrapper<AttemptOutcome> {
        let signedBody = prepared.body ?? Data()

        let headersWrapper = prepared.provider.createSignedHeadersWrapper(target: prepared.target) {
            signedBody
        }

        let sendOperation = BittensorAttestedRequestBuilder.createSendOperation(for: prepared, session: session) {
            guard
                let headers = try headersWrapper.targetOperation.extractNoCancellableResultData(),
                let clientId = headers[.clientId],
                clientId != refused?.clientId else {
                throw BittensorApiError.attestationFailure(requestId: refused?.requestId)
            }

            return headers
        }

        sendOperation.addDependency(headersWrapper.targetOperation)

        let gradeOperation = ClosureOperation<AttemptOutcome> { [self] in
            let signedClientId: String?

            do {
                signedClientId = try headersWrapper.targetOperation.extractNoCancellableResultData()?[.clientId]
            } catch {
                throw signingFailure(error, prepared: prepared, refused: refused)
            }

            let response: BittensorAttestedResponse

            do {
                response = try sendOperation.extractNoCancellableResultData()
            } catch let error as BittensorApiError {
                logger.warning("\(prepared.route) not sent: \(error)")

                throw error
            } catch {
                logger.warning("\(prepared.route) transport failure: \(error)")

                throw BittensorApiError.transport(error)
            }

            return try grade(response, prepared: prepared, signedClientId: signedClientId)
        }

        gradeOperation.addDependency(sendOperation)

        return CompoundOperationWrapper(
            targetOperation: gradeOperation,
            dependencies: headersWrapper.allOperations + [sendOperation]
        )
    }

    func signingFailure(
        _ error: Error,
        prepared: BittensorAttestedPreparedRequest,
        refused: RefusedAttempt?
    ) -> BittensorApiError {
        if BittensorAttestedResponseGrader.isChallengeRateLimit(error) {
            startChallengeCooldown()
        }

        let apiError = BittensorAttestedResponseGrader.mapSigningError(error)

        logger.warning("\(prepared.route) not signed: \(apiError)")

        return BittensorAttestedResponseGrader.carryingRequestId(refused?.requestId, in: apiError)
    }

    func grade(
        _ response: BittensorAttestedResponse,
        prepared: BittensorAttestedPreparedRequest,
        signedClientId: String?
    ) throws -> AttemptOutcome {
        let grade = BittensorAttestedResponseGrader.grade(
            response,
            isRecommendationsRoute: prepared.isRecommendationsRoute
        )

        log(response, grade: grade, route: prepared.route)

        switch grade {
        case let .success(rawResponse):
            return .response(rawResponse)
        case let .retryWithFreshProof(requestId):
            return .retry(RefusedAttempt(requestId: requestId, clientId: nil))
        case let .unknownClient(requestId):
            if let signedClientId {
                prepared.provider.markUnattested(ifCurrentClientId: signedClientId)
            }

            return .retry(RefusedAttempt(requestId: requestId, clientId: signedClientId))
        case let .failure(error):
            if case .attestationRejected = error {
                latchRejection()
            }

            throw error
        }
    }

    func log(_ response: BittensorAttestedResponse, grade: BittensorAttestedGrade, route: String) {
        let requestId = response.requestId ?? "-"

        guard case .success = grade else {
            let code = AttestationHTTP.rawErrorCode(from: response.body) ?? "-"

            logger.warning("\(route) -> \(response.statusCode) code \(code) request id \(requestId)")

            return
        }

        logger.debug("\(route) -> \(response.statusCode) request id \(requestId)")
    }
}
