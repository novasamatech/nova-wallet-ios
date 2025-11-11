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

        setupLayout()
        setupStyle()
    }
}

private extension GiftClaimSelectedWalletView {
    func setupStyle() {
        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.roundingCorners = .allCorners
        roundedBackgroundView.cornerRadius = Constants.cornerRadius
        borderView.borderType = []

        accessoryView.image = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        accessoryView.contentMode = .scaleAspectFit
    }

    func setupLayout() {
        contentInsets = Constants.contentInsets
        preferredHeight = UIConstants.actionHeight
        rowContentView.makeHorizontal()

        accessoryView.snp.makeConstraints { make in
            make.size.equalTo(Constants.accessorySize)
        }
    }
}

extension GiftClaimSelectedWalletView {
    func bind(viewModel: GiftClaimViewModel.WalletViewModel) {
        walletView.bind(viewModel: viewModel.walletViewModel)
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
        static let accessorySize: CGFloat = 24.0
    }
}
