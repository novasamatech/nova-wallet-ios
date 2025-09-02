import UIKit

extension LedgerDeviceModel {
    var approveTxImage: UIImage? {
        switch self {
        case .flex:
            R.image.imageLedgerTxApproveFlex()
        case .stax:
            R.image.imageLedgerTxApproveStax()
        case .nanoX, .unknown:
            R.image.imageLedgerApproveNanoX()
        }
    }

    var approveAddressImage: UIImage? {
        switch self {
        case .flex:
            R.image.imageLedgerAddressApproveFlex()
        case .stax:
            R.image.imageLedgerAddressApproveStax()
        case .nanoX, .unknown:
            R.image.imageLedgerApproveNanoX()
        }
    }

    var warningImage: UIImage? {
        switch self {
        case .flex:
            R.image.imageLedgerWarningFlex()
        case .stax:
            R.image.imageLedgerWarningStax()
        case .nanoX, .unknown:
            R.image.imageLedgerWarningNanoX()
        }
    }

    func approveTxText(for deviceName: String, locale: Locale) -> String {
        switch self {
        case .flex, .stax:
            R.string.localizable.ledgerFlexStaxSignTransactionDetails(
                deviceName,
                preferredLanguages: locale.rLanguages
            )
        case .nanoX, .unknown:
            R.string.localizable.ledgerSignTransactionDetails(
                deviceName,
                preferredLanguages: locale.rLanguages
            )
        }
    }

    func approveAddressText(for deviceName: String, locale: Locale) -> String {
        switch self {
        case .flex, .stax:
            R.string.localizable.ledgerFlexStaxAddressVerifyMessage(
                deviceName,
                preferredLanguages: locale.rLanguages
            )
        case .nanoX, .unknown:
            R.string.localizable.ledgerAddressVerifyMessage(
                deviceName,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}
