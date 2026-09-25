import Foundation
import Keystore_iOS
import Operation_iOS
import NovaAppAttest

final class BittensorAttestedTransport {
    private let holder: BittensorAttestationHolderProtocol
    private let environment: BittensorAttestedJobEnvironment

    init(
        holder: BittensorAttestationHolderProtocol,
        executor: BittensorAttestedRequestExecutor,
        session: URLSession = AttestationHTTP.session,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.holder = holder
        environment = BittensorAttestedJobEnvironment(
            executor: executor,
            session: session,
            operationQueue: operationQueue,
            logger: logger
        )
    }
}

extension BittensorAttestedTransport: BittensorApiTransportProtocol {
    func createResponseWrapper(
        for request: BittensorApiRequest
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        let contextWrapper = holder.createContextWrapper()

        let job = BittensorAttestedRequestJob(
            request: request,
            contextOperation: contextWrapper.targetOperation,
            environment: environment
        )

        let responseOperation = LongrunOperation<BittensorApiRawResponse>(longrun: AnyLongrun(longrun: job))

        responseOperation.addDependency(contextWrapper.targetOperation)

        return contextWrapper.insertingTail(operation: responseOperation)
    }
}

extension BittensorAttestedTransport {
    static let shared = BittensorAttestedTransport(
        holder: BittensorAttestationHolder(
            configProvider: GlobalConfigProvider.shared,
            appAttest: AppAttestService(),
            appIdentity: ApplicationConfig.shared.appAttestAppIdentity,
            isUnitTesting: ProcessInfo.processInfo.arguments.contains("-UNITTEST"),
            settingsManager: SettingsManager.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        ),
        executor: BittensorAttestedRequestExecutor(),
        operationQueue: OperationManagerFacade.sharedDefaultQueue,
        logger: Logger.shared
    )
}
