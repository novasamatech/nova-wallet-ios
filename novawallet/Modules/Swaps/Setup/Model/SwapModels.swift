import Foundation
import UIKit
import Foundation_iOS

struct SwapSetupInitState {
    let payChainAsset: ChainAsset?
    let receiveChainAsset: ChainAsset?
    let feeChainAsset: ChainAsset?
    let amount: Decimal?
    let direction: AssetConversion.Direction?

    init(
        payChainAsset: ChainAsset?,
        receiveChainAsset: ChainAsset? = nil,
        feeChainAsset: ChainAsset? = nil,
        amount: Decimal? = nil,
        direction: AssetConversion.Direction? = nil
    ) {
        self.payChainAsset = payChainAsset
        self.receiveChainAsset = receiveChainAsset
        self.feeChainAsset = feeChainAsset
        self.amount = amount
        self.direction = direction
    }
}

struct DepositOperationModel {
    let operation: TokenOperation
    let active: Bool
}

extension DepositOperationModel {
    func titleForLocale(_ locale: Locale) -> String {
        switch operation {
        case .send:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByCrossChainTransferTitle()
        case .receive:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.walletAssetReceive()
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.walletAssetBuy()
        }
    }

    func subtitleForLocale(_ locale: Locale, token: String) -> String {
        switch operation {
        case .send:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByCrossChainTransferSubtitle(token)
        case .receive:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByReceiveSubtitle(token)
        case .buy:
            return R.string(preferredLanguages: locale.rLanguages
            ).localizable.swapsSetupDepositByBuySubtitle(token)
        }
    }

    var icon: UIImage? {
        switch operation {
        case .send:
            return R.image.iconCrossChainTransfer()
        case .receive:
            return R.image.iconReceive()
        case .buy:
            return R.image.iconBuy()
        }
    }
}
