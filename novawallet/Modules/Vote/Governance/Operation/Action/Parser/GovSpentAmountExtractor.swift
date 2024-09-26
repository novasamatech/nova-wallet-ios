import Foundation
import SubstrateSdk
import Operation_iOS

protocol GovSpentAmountHandling {
    func handle(
        call: RuntimeCall<JSON>,
        internalHandlers: [GovSpentAmountHandling],
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]?
}

protocol GovSpendingExtracting {
    func createExtractionWrappers(
        from call: RuntimeCall<JSON>,
        context: GovSpentAmount.Context
    ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]?
}

enum GovSpentAmount {
    struct Context {
        let codingFactory: RuntimeCoderFactoryProtocol
        let connection: JSONRPCEngine
        let requestFactory: StorageRequestFactoryProtocol
    }

    final class Extractor: GovSpendingExtracting {
        let handlers: [GovSpentAmountHandling]

        init(handlers: [GovSpentAmountHandling]) {
            self.handlers = handlers
        }

        func createExtractionWrappers(
            from call: RuntimeCall<JSON>,
            context: GovSpentAmount.Context
        ) throws -> [CompoundOperationWrapper<ReferendumActionLocal.AmountSpendDetails?>]? {
            for handler in handlers {
                if let wrappers = try handler.handle(
                    call: call,
                    internalHandlers: handlers,
                    context: context
                ) {
                    return wrappers
                }
            }

            return nil
        }
    }
}

extension GovSpentAmount.Extractor {
    static func createDefaultExtractor(
        for chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) -> GovSpentAmount.Extractor {
        .init(
            handlers: [
                GovSpentAmount.BatchHandler(),
                GovSpentAmount.TreasurySpendLocalHandler(),
                GovSpentAmount.TreasuryApproveHandler(),
                GovSpentAmount.TreasurySpendRemoteHandler(
                    assetConversionFactory: CrosschainAssetConversionFactory(
                        baseChain: chain,
                        chainRegistry: chainRegistry,
                        operationQueue: operationQueue
                    ),
                    operationQueue: operationQueue
                )
            ]
        )
    }
}
