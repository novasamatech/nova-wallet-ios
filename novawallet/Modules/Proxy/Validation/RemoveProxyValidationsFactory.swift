import Foundation
import BigInt

final class RemoveProxyValidationsFactory: ProxyConfirmValidationsFactoryProtocol {
    let dataValidatingFactory: ProxyDataValidatorFactoryProtocol

    init(dataValidatingFactory: ProxyDataValidatorFactoryProtocol) {
        self.dataValidatingFactory = dataValidatingFactory
    }

    func validations(_ args: ConfirmProxyValidationArgs, locale: Locale) -> [DataValidating] {
        [
            dataValidatingFactory.validAddress(
                args.proxyAddress,
                chain: args.chainAsset.chain,
                locale: locale
            ),
            dataValidatingFactory.has(
                fee: args.fee,
                locale: locale,
                onError: args.feeFetchClosure
            ),
            dataValidatingFactory.canPayFeeInPlank(
                balance: args.assetBalance?.regularTransferrableBalance(),
                fee: args.fee,
                asset: args.chainAsset.assetDisplayInfo,
                locale: locale
            )
        ]
    }
}
