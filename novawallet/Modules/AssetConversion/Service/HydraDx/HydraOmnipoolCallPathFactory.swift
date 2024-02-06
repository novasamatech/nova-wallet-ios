import Foundation

struct HydraOmnipoolCallPathFactory: AssetConversionCallPathFactoryProtocol {
    func createHistoryCallPath(for args: AssetConversion.CallArgs) -> CallCodingPath {
        switch args.direction {
        case .sell:
            return HydraDx.SellCall.callPath
        case .buy:
            return HydraDx.BuyCall.callPath
        }
    }
}
