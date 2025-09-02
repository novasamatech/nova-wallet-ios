import Foundation
import UIKit.UIImage

struct SettingsAccountViewModel {
    let identifier: String
    let name: String
    let icon: UIImage?
    let walletType: WalletsListSectionViewModel.SectionType
    let hasWalletNotification: Bool
}
