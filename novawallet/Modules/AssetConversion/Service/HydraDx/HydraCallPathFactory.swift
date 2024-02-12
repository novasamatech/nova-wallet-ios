import Foundation

struct HydraCallPathFactory: AssetConversionCallPathFactoryProtocol {
    func createHistoryCallPath(for args: AssetConversion.CallArgs) -> CallCodingPath {
        // TODO: Check the calls when implement realtime history
        switch args.direction {
        case .sell:
            return HydraOmnipool.SellCall.callPath
        case .buy:
            return HydraOmnipool.BuyCall.callPath
        }
    }
}
