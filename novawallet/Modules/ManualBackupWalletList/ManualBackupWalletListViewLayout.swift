import UIKit

final class ManualBackupWalletListViewLayout: WalletsListViewLayout {
    let titleLabel: UILabel = {
        let label = UILabel(style: .boldTitle2Primary)
        label.lineBreakMode = .byWordWrapping

        return label
    }()
}
