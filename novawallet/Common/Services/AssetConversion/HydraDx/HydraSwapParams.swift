import Foundation

struct HydraSwapParams {
    struct Params {
        let newFeeCurrency: ChainAssetId
        let referral: AccountId?

        var shouldSetReferral: Bool {
            referral == nil
        }
    }

    enum Operation {
        case omniSell(HydraOmnipool.SellCall)
        case omniBuy(HydraOmnipool.BuyCall)
        case routedSell(HydraRouter.SellCall)
        case routedBuy(HydraRouter.BuyCall)
    }

    let params: Params
    let updateReferral: HydraDx.LinkReferralCodeCall?
    let swap: Operation
}
