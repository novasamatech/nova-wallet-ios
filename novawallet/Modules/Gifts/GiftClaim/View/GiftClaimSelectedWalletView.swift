import Foundation
import UIKit

final class GiftClaimSelectedWalletView: RowView<
    GenericPairValueView<
        WalletView,
        UIImageView
    >
> {
    private var walletView: WalletView {
        rowContentView.fView
    }

    private var accessoryView: UIImageView {
        rowContentView.sView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupStyle()
        setupLayout()
    }
}

private extension GiftClaimSelectedWalletView {
    func setupStyle() {
        roundedBackgroundView.cornerRadius = Constants.cornerRadius
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.strokeColor = .clear
        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
    }

    func setupLayout() {
        contentInsets = Constants.contentInsets
        rowContentView.makeHorizontal()
    }
}

extension GiftClaimSelectedWalletView {
    func bind(viewModel: GiftClaimViewModel.WalletViewModel) {
        walletView.bind(viewModel: viewModel.walletViewModel)
        walletView.bind(chainAccount: viewModel.addressViewModel)
    }
}

private extension GiftClaimSelectedWalletView {
    enum Constants {
        static let contentInsets = UIEdgeInsets(
            top: 0,
            left: 16.0,
            bottom: 0,
            right: 16.0
        )

        static let cornerRadius: CGFloat = 12.0
    }
}
