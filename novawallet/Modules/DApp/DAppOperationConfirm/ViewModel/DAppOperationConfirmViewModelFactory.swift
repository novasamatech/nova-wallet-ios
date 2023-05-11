import Foundation
import SubstrateSdk
import BigInt

protocol DAppOperationConfirmViewModelFactoryProtocol {
    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel
    func convertBalanceToDecimal(_ balance: BigUInt) -> Decimal?
}

final class DAppOperationConfirmViewModelFactory: DAppOperationConfirmViewModelFactoryProtocol {
    let chain: DAppEitherChain

    init(chain: DAppEitherChain) {
        self.chain = chain
    }

    func createViewModel(from model: DAppOperationConfirmModel) -> DAppOperationConfirmViewModel {
        let iconViewModel: ImageViewModelProtocol

        if let iconUrl = model.dAppIcon {
            iconViewModel = RemoteImageViewModel(url: iconUrl)
        } else {
            iconViewModel = StaticImageViewModel(image: R.image.iconDefaultDapp()!)
        }

        let walletIcon = model.walletIdenticon.flatMap { try? NovaIconGenerator().generateFromAccountId($0) }

        let addressIcon = try? PolkadotIconGenerator().generateFromAccountId(model.chainAccountId)

        let networkIcon: ImageViewModelProtocol?

        if let networkIconUrl = chain.networkIcon {
            networkIcon = RemoteImageViewModel(url: networkIconUrl)
        } else {
            networkIcon = nil
        }

        return DAppOperationConfirmViewModel(
            iconImageViewModel: iconViewModel,
            dApp: model.dApp,
            walletName: model.accountName,
            walletIcon: walletIcon,
            address: model.chainAddress.truncated,
            addressIcon: addressIcon,
            networkName: chain.networkName,
            networkIconViewModel: networkIcon
        )
    }

    func convertBalanceToDecimal(_ balance: BigUInt) -> Decimal? {
        guard let precision = chain.utilityAssetBalanceInfo?.assetPrecision else {
            return nil
        }

        return Decimal.fromSubstrateAmount(balance, precision: precision)
    }
}
