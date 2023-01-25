import Foundation
import RobinHood
import SubstrateSdk

class GovernanceActionOperationFactory {
    static let maxFetchCallSize: UInt32 = 1024

    let requestFactory: StorageRequestFactoryProtocol
    let operationQueue: OperationQueue

    init(requestFactory: StorageRequestFactoryProtocol, operationQueue: OperationQueue) {
        self.requestFactory = requestFactory
        self.operationQueue = operationQueue
    }

    func fetchCall(
        for _: Data,
        connection _: JSONRPCEngine,
        codingFactoryOperation _: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        fatalError("Must be overriden by child class")
    }

    private func createOpaqueCallParsingWrapper(
        for value: Data,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        let operation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

            let decoder = try codingFactory.createDecoder(from: value)

            let optCall: RuntimeCall<JSON>? = try? decoder.read(
                of: GenericType.call.name,
                with: codingFactory.createRuntimeJsonContext().toRawContext()
            )

            if let call = optCall {
                return .concrete(call)
            } else {
                return nil
            }
        }

        return CompoundOperationWrapper(targetOperation: operation)
    }

    private func createCallFetchWrapper(
        dependingOn codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        referendum: ReferendumLocal,
        requestFactory _: StorageRequestFactoryProtocol,
        connection: JSONRPCEngine
    ) -> CompoundOperationWrapper<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
        let callDecodingService = OperationCombiningService<ReferendumActionLocal.Call<RuntimeCall<JSON>>?>(
            operationManager: OperationManager(operationQueue: operationQueue)
        ) {
            switch referendum.state.proposal {
            case let .legacy(hash):
                let wrapper = self.fetchCall(
                    for: hash,
                    connection: connection,
                    codingFactoryOperation: codingFactoryOperation
                )
                return [wrapper]
            case let .inline(value):
                let wrapper = self.createOpaqueCallParsingWrapper(
                    for: value.wrappedValue,
                    codingFactoryOperation: codingFactoryOperation
                )

                return [wrapper]
            case let .lookup(lookup):
                if lookup.len <= Self.maxFetchCallSize {
                    let wrapper = self.fetchCall(
                        for: lookup.hash,
                        connection: connection,
                        codingFactoryOperation: codingFactoryOperation
                    )

                    return [wrapper]
                } else {
                    return [CompoundOperationWrapper.createWithResult(.tooLong)]
                }
            case .none, .unknown:
                return []
            }
        }

        let callDecodingOperation = callDecodingService.longrunOperation()
        let mappingOperation = ClosureOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?> {
            try callDecodingOperation.extractNoCancellableResultData().first ?? nil
        }

        mappingOperation.addDependency(callDecodingOperation)

        return CompoundOperationWrapper(targetOperation: mappingOperation, dependencies: [callDecodingOperation])
    }

    private func createSpendAmountExtractionWrapper(
        dependingOn callOperation: BaseOperation<ReferendumActionLocal.Call<RuntimeCall<JSON>>?>,
        codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
        connection: JSONRPCEngine,
        requestFactory: StorageRequestFactoryProtocol
    ) -> CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?> {
        let operationManager = OperationManager(operationQueue: operationQueue)
        let fetchService = OperationCombiningService<ReferendumActionLocal.AmountSpendDetails?>(
            operationManager: operationManager
        ) {
            guard let call = try callOperation.extractNoCancellableResultData()?.value else {
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

extension GovernanceActionOperationFactory: ReferendumActionOperationFactoryProtocol {
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
