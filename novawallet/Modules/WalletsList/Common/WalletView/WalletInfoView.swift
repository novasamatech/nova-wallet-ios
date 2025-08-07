import Foundation
import UIKit

final class WalletInfoView<T: WalletViewProtocol>: GenericPairValueView<T, UIImageView> {
    var walletView: WalletViewProtocol { fView }
    var infoIndicatorImageView: UIImageView { sView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }
}

private extension WalletInfoView {
    func setupLayout() {
        makeHorizontal()

        infoIndicatorImageView.snp.makeConstraints { make in
            make.size.equalTo(16.0)
        }

        walletView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )
        infoIndicatorImageView.setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )
        stackView.spacing = 8.0
        stackView.distribution = .fillProportionally
    }

    func setupStyle() {
        infoIndicatorImageView.image = R.image.iconInfoFilled()
        infoIndicatorImageView.contentMode = .scaleAspectFit
    }
}

extension WalletInfoView: WalletViewProtocol {
    var iconTitleSpacing: CGFloat {
        get {
            walletView.iconTitleSpacing
        }
        set {
            walletView.iconTitleSpacing = newValue
        }
    }

    var viewModel: ViewModel? {
        get {
            walletView.viewModel
        }
        set {
            walletView.viewModel = newValue
        }
    }

    var iconContainerView: WalletIconView { walletView.iconContainerView }

    var iconImageView: UIImageView { walletView.iconImageView }

    var titleLabel: UILabel { walletView.titleLabel }

    var networkImageView: UIImageView { walletView.networkImageView }

    func bind(delegatedAccount viewModel: ViewModel.DelegatedAccountInfo) {
        walletView.bind(delegatedAccount: viewModel)
    }

    func bind(regular viewModel: ViewModel.BalanceInfo) {
        walletView.bind(regular: viewModel)
    }

    func cancelIconsLoading(info: ViewModel.DelegatedAccountInfo?) {
        walletView.cancelIconsLoading(info: info)
    }

    func setAppearance(for selectionAvailable: Bool) {
        walletView.setAppearance(for: selectionAvailable)
    }

    func bindNoInfo() {
        walletView.bindNoInfo()
    }
}
