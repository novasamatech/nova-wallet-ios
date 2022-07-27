import UIKit

class WalletSelectionViewLayout: WalletsListViewLayout {
    let settingsButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.image = R.image.iconSettings()
        return button
    }()
}
