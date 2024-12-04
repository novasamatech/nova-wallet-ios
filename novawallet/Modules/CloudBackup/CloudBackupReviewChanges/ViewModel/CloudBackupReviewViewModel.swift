import Foundation

struct CloudBackupReviewItemViewModel {
    enum ChangeType {
        case new
        case modified
        case removed
    }

    let metaId: MetaAccountModel.Id
    let walletViewModel: WalletView.ViewModel.WalletInfo
    let changeType: ChangeType
}

struct CloudBackupReviewSectionViewModel: SectionProtocol {
    let header: TitleIconViewModel?
    var cells: [CloudBackupReviewItemViewModel]
}

extension CloudBackupReviewItemViewModel.ChangeType: Hashable {}
extension CloudBackupReviewItemViewModel: Hashable {}
extension CloudBackupReviewSectionViewModel: Hashable {}
