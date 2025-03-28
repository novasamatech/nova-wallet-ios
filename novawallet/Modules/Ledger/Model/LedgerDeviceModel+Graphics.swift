import UIKit

extension LedgerDeviceModel {
    var approveViewModel: UIImage? {
        switch self {
        case .flex:
            R.image.imageLedgerApproveFlex()
        case .stax:
            R.image.imageLedgerApproveStax()
        case .nanoX, .unknown:
            R.image.imageLedgerApproveNanoX()
        }
    }

    var warningViewModel: UIImage? {
        switch self {
        case .flex:
            R.image.imageLedgerWarningFlex()
        case .stax:
            R.image.imageLedgerWarningStax()
        case .nanoX, .unknown:
            R.image.imageLedgerWarningNanoX()
        }
    }
}
