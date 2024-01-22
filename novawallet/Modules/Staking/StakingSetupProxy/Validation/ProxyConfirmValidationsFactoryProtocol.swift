import Foundation
import BigInt

struct ConfirmProxyValidationArgs {
    let proxyAddress: AccountAddress
    let chainAsset: ChainAsset
    let proxy: UncertainStorage<ProxyDefinition?>
    let limitProxyCount: Int?
    let feeFetchClosure: () -> Void
    let assetBalance: AssetBalance?
    let proxyDeposit: ProxyDeposit?
    let existensialDeposit: BigUInt?
    let fee: ExtrinsicFeeProtocol?
}

protocol ProxyConfirmValidationsFactoryProtocol {
    func validations(_ args: ConfirmProxyValidationArgs, locale: Locale) -> [DataValidating]
}
