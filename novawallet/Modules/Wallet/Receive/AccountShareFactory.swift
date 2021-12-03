import Foundation
import CommonWallet
import SoraFoundation
import SoraKeystore

final class AccountShareFactory: AccountShareFactoryProtocol {
    let chain: ChainModel
    let assetInfo: AssetBalanceDisplayInfo
    let localizationManager: LocalizationManagerProtocol

    init(
        chain: ChainModel,
        assetInfo: AssetBalanceDisplayInfo,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.chain = chain
        self.assetInfo = assetInfo
        self.localizationManager = localizationManager
    }

    func createSources(for info: ReceiveInfo, qrImage: UIImage) -> [Any] {
        guard
            let accountId = try? Data(hexString: info.accountId),
            let address = try? accountId.toAddress(using: chain.chainFormat) else {
            return []
        }

        let locale = localizationManager.selectedLocale

        let message = R.string.localizable
            .walletReceiveShareMessage(chain.name, assetInfo.symbol, preferredLanguages: locale.rLanguages)

        return [qrImage, message, address]
    }
}
