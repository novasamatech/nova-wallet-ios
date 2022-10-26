import Foundation
import RobinHood
import SubstrateSdk

final class Gov2ActionOperationFactory {
    static let maxFetchCallSize: UInt32 = 1024

    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    private func createCallFetchWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        referendum: ReferendumLocal,
        requestFactory: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<RuntimeCall<JSON>?> {
        let callFetchClosure: (Data) -> CompoundOperationWrapper<RuntimeCall<JSON>?> = { hash in
            let statusKeyParams: () throws -> [BytesCodable] = {
                [BytesCodable(wrappedValue: hash)]
            }

            let statusFetchWrapper: CompoundOperationWrapper<[StorageResponse<Preimage.RequestStatus>]> =
                requestFactory.queryItems(
                    engine: connection,
                    keyParams: statusKeyParams,
                    factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                    storagePath: Preimage.statusForStoragePath
                )

            let callKeyParams: () throws -> [Preimage.PreimageKey] = {
                let status = try statusFetchWrapper.targetOperation.extractNoCancellableResultData().first?.value

                guard let length = status?.length else {
                    return []
                }

                return [Preimage.PreimageKey(hash: hash, length: length)]
            }

            let callFetchWrapper: CompoundOperationWrapper<[StorageResponse<BytesCodable>]> = requestFactory.queryItems(
                engine: connection,
                keyParams: callKeyParams,
                factory: { try codingFactoryOperation.extractNoCancellableResultData() },
                storagePath: Preimage.preimageForStoragePath
            )

            callFetchWrapper.addDependency(wrapper: statusFetchWrapper)

            let mappingOperation = ClosureOperation<RuntimeCall<JSON>?> {
                let callKeys = try callKeyParams()

                guard !callKeys.isEmpty else {
                    return nil
                }

                let responses = try callFetchWrapper.targetOperation.extractNoCancellableResultData()
                guard let response = responses.first?.value else {
                    return nil
                }

                let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                let decoder = try codingFactory.createDecoder(from: response.wrappedValue)

                return try decoder.read(
                    of: GenericType.call.name,
                    with: codingFactory.createRuntimeJsonContext().toRawContext()
                )
            }

            mappingOperation.addDependency(callFetchWrapper.targetOperation)

            let dependencies = statusFetchWrapper.allOperations + callFetchWrapper.allOperations

            return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: dependencies)
        }

        let callDecodingService = OperationCombiningService<RuntimeCall<JSON>?>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            switch referendum.state.proposal {
            case let .legacy(hash):
                let wrapper = callFetchClosure(hash)
                return [wrapper]
            case let .inline(value):
                return [CompoundOperationWrapper.createWithResult(value)]
            case let .lookup(lookup):
                if lookup.len <= Self.maxFetchCallSize {
                    let wrapper = callFetchClosure(lookup.hash)
                    return [wrapper]
                } else {
                    return []
                }
            case .none, .unknown:
                return []
            }
        }

        let callDecodingOperation = callDecodingService.longrunOperation()
        let mappingOperation = ClosureOperation<RuntimeCall<JSON>?> {
            try callDecodingOperation.extractNoCancellableResultData().first ?? nil
        }

        mappingOperation.addDependency(callDecodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [callDecodingOperation])
    }

    private func createSpendAmountExtractionWrapper(
        dependingOn callOperation: BaseOperation<RuntimeCall<JSON>?>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine,
        requestFactory: StorageRequestFactoryProtocol
    ) -> CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?> {
        let operationManager = OperationManager(operationQueue: operationQueue)
        let fetchService = OperationCombiningService<ReferendumActionLocal.AmountSpendDetails?>(
            operationManager: operationManager
        ) {
            guard let call = try callOperation.extractNoCancellableResultData() else {
                return [CompoundOperationWrapper.createWithResult(nil)]
            }

            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            let context = codingFactory.createRuntimeJsonContext()

            let codingPath = CallCodingPath(moduleName: call.moduleName, callName: call.callName)

            if codingPath == Treasury.spendCallPath {
                let spendCall = try call.args.map(to: Treasury.SpendCall.self, with: context.toRawContext())

                let details = ReferendumActionLocal.AmountSpendDetails(
                    amount: spendCall.amount,
                    beneficiary: spendCall.beneficiary
                )

                return [CompoundOperationWrapper.createWithResult(details)]
            }

            if codingPath == Treasury.approveProposalCallPath {
                let approveCall = try call.args.map(to: Treasury.ApproveProposal.self, with: context.toRawContext())

                let keyClosure: () throws -> [StringScaleMapper<Treasury.ProposalIndex>] = {
                    [StringScaleMapper(value: approveCall.proposalId)]
                }

                let wrapper: CompoundOperationWrapper<[StorageResponse<Treasury.Proposal>]> = requestFactory.queryItems(
                    engine: connection,
                    keyParams: keyClosure,
                    factory: { codingFactory },
                    storagePath: Treasury.proposalsStoragePath
                )

                let mapOperation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
                    let responses = try wrapper.targetOperation.extractNoCancellableResultData()
                    guard let proposal = responses.first?.value else {
                        return nil
                    }

                    return ReferendumActionLocal.AmountSpendDetails(
                        amount: proposal.value,
                        beneficiary: .accoundId(proposal.beneficiary)
                    )
                }

                mapOperation.addDependency(wrapper.targetOperation)

                return [CompoundOperationWrapper(targetOperation: mapOperation, dependencies: wrapper.allOperations)]
            }

            return [CompoundOperationWrapper.createWithResult(nil)]
        }

        let fetchOperation = fetchService.longrunOperation()

        let mapOperation = ClosureOperation<ReferendumActionLocal.AmountSpendDetails?> {
            try fetchOperation.extractNoCancellableResultData().first ?? nil
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }
}

extension Gov2ActionOperationFactory: ReferendumActionOperationFactoryProtocol {
    func fetchActionWrapper(
        for referendum: ReferendumLocal,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> CompoundOperationWrapper<ReferendumActionLocal> {
        let codingFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let callFetchWrapper = createCallFetchWrapper(
            dependingOn: codingFactoryOperation,
            referendum: referendum,
            requestFactory: requestFactory,
            connection: connection
        )

        callFetchWrapper.addDependency(operations: [codingFactoryOperation])

        let amountDetailsWrapper = createSpendAmountExtractionWrapper(
            dependingOn: callFetchWrapper.targetOperation,
            codingFactoryOperation: codingFactoryOperation,
            connection: connection,
            requestFactory: requestFactory
        )

        amountDetailsWrapper.addDependency(wrapper: callFetchWrapper)
        amountDetailsWrapper.addDependency(operations: [codingFactoryOperation])

        let mapOperation = ClosureOperation<ReferendumActionLocal> {
            let call = try callFetchWrapper.targetOperation.extractNoCancellableResultData()
            let amountDetails = try amountDetailsWrapper.targetOperation.extractNoCancellableResultData()

            return ReferendumActionLocal(amountSpendDetails: amountDetails, call: call)
        }

        mapOperation.addDependency(callFetchWrapper.targetOperation)
        mapOperation.addDependency(amountDetailsWrapper.targetOperation)

        let dependencies = [codingFactoryOperation] + callFetchWrapper.allOperations +
            amountDetailsWrapper.allOperations

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }
}
