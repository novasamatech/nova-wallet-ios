import Foundation
import SubstrateSdk

extension SubtensorStakingPallet {
    static var stakeInfoForColdkeyApi: StateCallPath {
        StateCallPath(module: stakeInfoApiName, method: "get_stake_info_for_coldkey")
    }

    static var stakeAvailabilityForColdkeysApi: StateCallPath {
        StateCallPath(module: stakeInfoApiName, method: "get_stake_availability_for_coldkeys")
    }

    static var allDynamicInfoApi: StateCallPath {
        StateCallPath(module: subnetInfoApiName, method: "get_all_dynamic_info")
    }

    static var delegatesApi: StateCallPath {
        StateCallPath(module: delegateInfoApiName, method: "get_delegates")
    }

    static var alphaPriceAllApi: StateCallPath {
        StateCallPath(module: swapApiName, method: "current_alpha_price_all")
    }

    static var alphaPriceApi: StateCallPath {
        StateCallPath(module: swapApiName, method: "current_alpha_price")
    }

    static var simSwapTaoForAlphaApi: StateCallPath {
        StateCallPath(module: swapApiName, method: "sim_swap_tao_for_alpha")
    }

    static var simSwapAlphaForTaoApi: StateCallPath {
        StateCallPath(module: swapApiName, method: "sim_swap_alpha_for_tao")
    }

    static var rootBasketOwedApi: StateCallPath {
        StateCallPath(module: betaBasketApiName, method: "get_root_basket_owed")
    }

    static var rootBasketPositionsApi: StateCallPath {
        StateCallPath(module: betaBasketApiName, method: "get_root_basket_positions")
    }

    /// network-wide beta basket NAV; sampled across two blocks it is the observed TAO flow to
    /// root stakers, which is what the spec §6.2 release gate validates the engine against
    /// (subtensor: `pallets/subtensor/src/staking/basket_views.rs:112-124`)
    static var rootBasketTotalNavApi: StateCallPath {
        StateCallPath(module: betaBasketApiName, method: "get_root_basket_total_nav")
    }
}
