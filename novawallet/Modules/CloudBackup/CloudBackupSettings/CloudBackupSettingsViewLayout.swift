import UIKit

final class CloudBackupSettingsViewLayout: ScrollableContainerLayoutView {
    let cloudTitle: UILabel = .create { label in
        label.apply(style: .title3Primary)
    }
}
