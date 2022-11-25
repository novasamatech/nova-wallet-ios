import Foundation
import BigInt

final class ChainBalanceViewModelFactory {
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()) {
        self.formatterFactory = formatterFactory
    }

    func createViewModel(
        from title: String,
        chainAsset: ChainAsset,
        balanceInPlank: BigUInt?,
        locale: Locale
    ) -> ChainBalanceViewModel {
        let displayInfo = chainAsset.assetDisplayInfo
        let tokenFormatter = formatterFactory.createTokenFormatter(for: displayInfo)

        let icon = RemoteImageViewModel(url: chainAsset.asset.icon ?? chainAsset.chain.icon)

        if
            let balanceInPlank = balanceInPlank,
            let decimalBalance = Decimal.fromSubstrateAmount(balanceInPlank, precision: displayInfo.assetPrecision) {
            let balanceString = tokenFormatter.value(for: locale).stringFromDecimal(decimalBalance)

            return ChainBalanceViewModel(name: title, icon: icon, balance: balanceString)
        } else {
            return ChainBalanceViewModel(name: title, icon: icon, balance: nil)
        }
    }

    func createViewModel(
        from chainAsset: ChainAsset,
        balanceInPlank: BigUInt?,
        locale: Locale
    ) -> ChainBalanceViewModel {
        let name = chainAsset.chain.name

        return createViewModel(
            from: name,
            chainAsset: chainAsset,
            balanceInPlank: balanceInPlank,
            locale: locale
        )
    }
}
