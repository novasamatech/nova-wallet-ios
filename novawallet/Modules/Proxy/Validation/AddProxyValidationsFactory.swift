import Foundation
import BigInt

final class AddProxyValidationsFactory: ProxyConfirmValidationsFactoryProtocol {
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
            dataValidatingFactory.proxyNotExists(
                address: args.proxyAddress,
                chain: args.chainAsset.chain,
                proxyList: args.proxy.map { $0?.definition ?? [] }.value,
                locale: locale
            ),
            dataValidatingFactory.notReachedMaximimProxyCount(
                args.proxy.map { $0?.definition.count ?? 0 }.value.map { $0 + 1 },
                limit: args.limitProxyCount,
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
            ),
            dataValidatingFactory.hasSufficientBalance(
                available: (args.assetBalance?.regularTransferrableBalance() ?? 0) + (args.proxyDeposit?.current ?? 0),
                deposit: args.proxyDeposit?.new,
                fee: args.fee?.amountForCurrentAccount,
                asset: args.chainAsset.assetDisplayInfo,
                locale: locale
            ),
            dataValidatingFactory.exsitentialDepositIsNotViolated(
                spendingAmount: args.fee?.amountForCurrentAccount,
                totalAmount: args.assetBalance?.freeInPlank,
                minimumBalance: args.existensialDeposit,
                locale: locale
            )
        ]
    }
}
