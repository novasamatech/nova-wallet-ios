import Foundation
import BigInt
import SubstrateSdk

extension HydraRouter {
    static var routeExecutedPath: EventCodingPath {
        .init(moduleName: HydraRouter.moduleName, eventName: "Executed")
    }

    struct RouteExecutedEvent: Codable {
        let assetIn: HydraDx.AssetId
        let assetOut: HydraDx.AssetId
        let amountIn: BigUInt
        let amountOut: BigUInt

        init(from decoder: Decoder) throws {
            var unkeyedContainer = try decoder.unkeyedContainer()

            assetIn = try unkeyedContainer.decode(StringScaleMapper<HydraDx.AssetId>.self).value
            assetOut = try unkeyedContainer.decode(StringScaleMapper<HydraDx.AssetId>.self).value
            amountIn = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
            amountOut = try unkeyedContainer.decode(StringScaleMapper<BigUInt>.self).value
        }
    }
}
