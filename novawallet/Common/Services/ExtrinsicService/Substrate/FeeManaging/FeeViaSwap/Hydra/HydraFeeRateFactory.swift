import Foundation
import Operation_iOS

final class HydraFeeQuoteFactory {
    let realQuoteFactory: AssetQuoteFactoryProtocol
    let tokensFactory: HydraTokensFactoryProtocol
    let operationQueue: OperationQueue

    init(
        realQuoteFactory: AssetQuoteFactoryProtocol,
        tokensFactory: HydraTokensFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.realQuoteFactory = realQuoteFactory
        self.tokensFactory = tokensFactory
        self.operationQueue = operationQueue
    }
}

private extension HydraFeeQuoteFactory {
    func createFallbackPriceWrapper(
        for args: AssetConversion.QuoteArgs
    ) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let fallbackPriceWrapper = tokensFactory.fallbackFeePrice(for: args.assetIn)

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
