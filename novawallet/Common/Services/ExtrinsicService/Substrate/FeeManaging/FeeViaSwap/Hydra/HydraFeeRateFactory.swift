import Foundation
import Operation_iOS

final class HydraFeeQuoteFactory {
    let priceFactory: HydraFeeOraclePriceFactoryProtocol

    init(priceFactory: HydraFeeOraclePriceFactoryProtocol) {
        self.priceFactory = priceFactory
    }
}

extension HydraFeeQuoteFactory: AssetQuoteFactoryProtocol {
    func quote(for args: AssetConversion.QuoteArgs) -> CompoundOperationWrapper<AssetConversion.Quote> {
        let priceWrapper = priceFactory.createPriceWrapper(for: args.assetIn)

        let mapOperation = ClosureOperation<AssetConversion.Quote> {
            let price = try priceWrapper.targetOperation.extractNoCancellableResultData()

            let converted = HydraFeeConversion.convertFee(args.amount, price: price)

            return AssetConversion.Quote(args: args, amount: converted, context: nil)
        }

        mapOperation.addDependency(priceWrapper.targetOperation)

        return priceWrapper.insertingTail(operation: mapOperation)
    }
}
