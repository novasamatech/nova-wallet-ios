import Foundation

struct AssetHubCallPathFactory: AssetConversionCallPathFactoryProtocol {
    func createHistoryCallPath(for args: AssetConversion.CallArgs) -> CallCodingPath {
        AssetConversionPallet.callPath(for: args.direction)
    }
}
