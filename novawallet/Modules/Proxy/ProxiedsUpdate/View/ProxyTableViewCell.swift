import Foundation
import UIKit
import SoraUI

final class ProxyTableViewCell: PlainBaseTableViewCell<WalletView> {
    override func prepareForReuse() {
        super.prepareForReuse()

        contentDisplayView.cancelImagesLoading()
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = .clear
    }

    func bind(viewModel: WalletView.ViewModel) {
        contentDisplayView.bind(viewModel: viewModel)
    }
}
