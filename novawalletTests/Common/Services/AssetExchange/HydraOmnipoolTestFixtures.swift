import Foundation
@testable import novawallet
import BigInt

enum HydraOmnipoolTestFixtures {
    static func params(assetInBalance: BigUInt, assetOutBalance: BigUInt) throws -> HydraOmnipoolApi.Params {
        HydraOmnipoolApi.Params(
            assetInState: try assetState(hubReserve: assetInBalance),
            assetOutState: try assetState(hubReserve: assetOutBalance),
            assetInBalance: assetInBalance,
            assetOutBalance: assetOutBalance,
            assetFee: 0,
            protocolFee: 0,
            maxSlipFee: 0
        )
    }

    private static func assetState(hubReserve: BigUInt) throws -> HydraOmnipool.AssetState {
        let json = """
        {
            "hubReserve": "\(hubReserve)",
            "shares": "\(hubReserve)",
            "protocolShares": "0",
            "tradable": { "bits": "3" }
        }
        """

        return try JSONDecoder().decode(HydraOmnipool.AssetState.self, from: Data(json.utf8))
    }
}
