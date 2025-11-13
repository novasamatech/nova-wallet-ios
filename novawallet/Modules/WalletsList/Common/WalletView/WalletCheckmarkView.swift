import Foundation
import UIKit

final class WalletInfoControl: RowView<
    WalletInfoView<WalletView>
> {
    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        preferredHeight = 48.0
    }

    func bind(viewModel: WalletInfoView<WalletView>.ViewModel) {
        rowContentView.bind(viewModel: viewModel)
    }
}

final class WalletInfoCheckmarkControl: RowView<
    WalletCheckmarkView<
        WalletInfoView<WalletView>
    >
> {
    var model: WalletsCheckmarkViewModel?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        preferredHeight = 48
    }

    func bind(viewModel: WalletsCheckmarkViewModel) {
        model = viewModel

        rowContentView.bind(viewModel: viewModel)
    }
}

final class WalletCheckmarkView<T: WalletViewProtocol>: GenericTitleValueView<T, UIImageView> {
    var walletView: WalletViewProtocol { titleView }
    var checkMarkView: UIImageView { valueView }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    func bind(viewModel: WalletsCheckmarkViewModel) {
        walletView.bind(viewModel: viewModel.walletViewModel)

        if viewModel.checked {
            checkMarkView.image = R.image.iconCheckmarkFilled()?.tinted(
                with: R.color.colorIconPositive()!
            )
        } else {
            checkMarkView.image = nil
        }

        walletView.titleLabel.lineBreakMode = viewModel.walletViewModel.wallet.lineBreakMode
    }
}

private extension WalletCheckmarkView {
    func setupLayout() {
        spacing = 52.0

        checkMarkView.snp.makeConstraints { make in
            make.size.equalTo(24.0)
        }
    }
}

extension WalletCheckmarkView: WalletViewProtocol {
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

    func bind(chainAccount viewModel: ViewModel.ChainAccountAddressInfo) {
        walletView.bind(chainAccount: viewModel)
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

extension WalletInfoCheckmarkControl: StackTableViewCellProtocol {}
