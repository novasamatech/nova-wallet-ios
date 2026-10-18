import Foundation
import NovaAuth
import Operation_iOS

final class BittensorAuthorizedTransport: BittensorApiTransportProtocol {
    private let provider: NovaAuthProvidingProtocol
    private let operationQueue: OperationQueue

    init(provider: NovaAuthProvidingProtocol, operationQueue: OperationQueue) {
        self.provider = provider
        self.operationQueue = operationQueue
    }

    var invalidationRevision: UInt64 {
        provider.endpointAvailability.invalidationRevision
    }

    func addInvalidationObserver(_ owner: AnyObject, closure: @escaping (UInt64) -> Void) -> UInt64 {
        provider.addAvailabilityObserver(owner) { availability in
            closure(availability.invalidationRevision)
        }.invalidationRevision
    }

    func createAdmissionWrapper() -> CompoundOperationWrapper<BittensorApiAdmission> {
        let endpointWrapper = provider.createEndpointWrapper()
        let admission = OperationCombiningService<BittensorApiAdmission>.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            let endpoint: NovaAuthEndpoint
            do {
                endpoint = try endpointWrapper.targetOperation.extractNoCancellableResultData()
            } catch { throw BittensorAuthorizedResponseGrader.map(error) }
            let check = endpoint.client.createAdmissionWrapper(in: endpoint.context)
            let map = ClosureOperation<BittensorApiAdmission> {
                do {
                    try check.targetOperation.extractNoCancellableResultData()
                } catch { throw BittensorAuthorizedResponseGrader.map(error) }
                return BittensorApiAdmission(
                    scope: BittensorApiCacheScope(
                        origin: endpoint.context.origin.value,
                        generation: endpoint.context.generation,
                        invalidationRevision: endpoint.invalidationRevision
                    ),
                    endpoint: endpoint
                )
            }
            map.addDependency(check.targetOperation)
            return check.insertingTail(operation: map)
        }
        admission.addDependency(wrapper: endpointWrapper)
        return admission.insertingHead(operations: endpointWrapper.allOperations)
    }

    func createResponseWrapper(
        for request: BittensorApiRequest,
        admission: BittensorApiAdmission
    ) -> CompoundOperationWrapper<BittensorApiRawResponse> {
        do {
            let prepared = try prepare(request, endpoint: admission.endpoint)
            let response = admission.endpoint.client.createResponseWrapper(for: prepared, beforeSend: {})
            let grade = ClosureOperation<BittensorApiRawResponse> {
                do {
                    return try BittensorAuthorizedResponseGrader.grade(
                        response.targetOperation.extractNoCancellableResultData()
                    )
                } catch { throw BittensorAuthorizedResponseGrader.map(error) }
            }
            grade.addDependency(response.targetOperation)
            return response.insertingTail(operation: grade)
        } catch { return .createWithError(BittensorAuthorizedResponseGrader.map(error)) }
    }

    static let shared = BittensorAuthorizedTransport(
        provider: NovaAuthFacade.shared,
        operationQueue: OperationManagerFacade.sharedDefaultQueue
    )
}

private extension BittensorAuthorizedTransport {
    func prepare(_ request: BittensorApiRequest, endpoint: NovaAuthEndpoint) throws -> NovaAuthRequest {
        try NovaAuthRequest(
            context: endpoint.context,
            method: .get,
            path: "/v1/bittensor" + request.path,
            queryItems: request.queryItems,
            body: nil,
            contentType: nil,
            intent: .userDriven
        )
    }
}
