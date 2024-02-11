import Foundation

struct HydraCallPathFactory: AssetConversionCallPathFactoryProtocol {
    func createHistoryCallPath(for args: AssetConversion.CallArgs) -> CallCodingPath {
        // TODO: We might have other calls
        switch args.direction {
        case .sell:
            return HydraDx.SellCall.callPath
        case .buy:
            return HydraDx.BuyCall.callPath
        }
    }
}
