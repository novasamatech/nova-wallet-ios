import Foundation
import Operation_iOS
import SubstrateSdk
import BigInt

final class HydraFeeQuoteFactory {
    let chain: ChainModel
    let realQuoteFactory: AssetQuoteFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeService: RuntimeProviderProtocol
    let operationQueue: OperationQueue

    init(
        chain: ChainModel,
        realQuoteFactory: AssetQuoteFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeService: RuntimeProviderProtocol,
        operationQueue: OperationQueue
    ) {
        self.chain = chain
        self.realQuoteFactory = realQuoteFactory
        self.connection = connection
        self.runtimeService = runtimeService
        self.operationQueue = operationQueue
    }
}

private extension HydraFeeQuoteFactory {
    func fallbackFeePrice(for chainAssetId: ChainAssetId) -> CompoundOperationWrapper<BigRational?> {
        do {
            let chainAsset = try chain.chainAssetOrError(for: chainAssetId.assetId)
            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let requestFactory = StorageRequestFactory(
                remoteFactory: StorageKeyFactory(),
                operationManager: OperationManager(operationQueue: operationQueue)
            )

            let fetchWrapper: CompoundOperationWrapper<[StorageResponse<StringScaleMapper<BigUInt>>]>
            fetchWrapper = requestFactory.queryItems(
                engine: connection,
                keyParams: {
                    let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()

                    let conversion = try HydraDxTokenConverter.convertToRemote(
                        chainAsset: chainAsset,
                        codingFactory: codingFactory
                    )

                    let remoteAssetId = conversion.remoteAssetId

                    return [StringScaleMapper(value: remoteAssetId)]

                }, factory: {
                    try codingFactoryOperation.extractNoCancellableResultData()
                },
                storagePath: HydraDx.feeCurrenciesPath
            )

            fetchWrapper.addDependency(operations: [codingFactoryOperation])

            let mapOperation = ClosureOperation<BigRational?> {
                let responses = try fetchWrapper.targetOperation.extractNoCancellableResultData()

                guard let price = responses.first?.value?.value else {
                    return nil
                }

                return .fixedU128(value: price)
            }

            mapOperation.addDependency(fetchWrapper.targetOperation)

            return fetchWrapper
                .insertingHead(operations: [codingFactoryOperation])
                .insertingTail(operation: mapOperation)
        } catch {
            return .createWithError(error)
        }
    }

    func createFallbackPriceWrapper(
        for args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let fallbackPriceWrapper = fallbackFeePrice(for: args.assetIn)

        let mapOperation = ClosureOperation<AssetConversion.Quote> {
            let optPrice = try fallbackPriceWrapper.targetOperation.extractNoCancellableResultData()

            guard let price = optPrice else {
                throw AssetConversionOperationError.noRoutesAvailable
            }

            let amountOut = price.mul(value: args.amount)

            return AssetConversion.Quote(
                args: args,
                amount: amountOut,
                context: nil
            )
        }

        mapOperation.addDependency(fallbackPriceWrapper.targetOperation)

        return fallbackPriceWrapper.insertingTail(operation: mapOperation)
    }
}

extension HydraFeeQuoteFactory: AssetQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let quoteWrapper = realQuoteFactory.quote(for: args)

        let fallbackWrapper = OperationCombiningService.compoundNonOptionalWrapper(
            operationQueue: operationQueue
        ) {
            do {
                let quote = try quoteWrapper.targetOperation.extractNoCancellableResultData()

                return CompoundOperationWrapper.createWithResult(quote)
            } catch AssetConversionOperationError.noRoutesAvailable {
                return self.createFallbackPriceWrapper(for: args)
            }
        }

        fallbackWrapper.addDependency(wrapper: quoteWrapper)

        return fallbackWrapper.insertingHead(operations: quoteWrapper.allOperations)
    }
}
