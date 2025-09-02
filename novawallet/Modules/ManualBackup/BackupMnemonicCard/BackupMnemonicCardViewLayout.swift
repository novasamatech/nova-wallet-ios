import UIKit
import UIKit_iOS
import SnapKit

final class BackupMnemonicCardViewLayout: ScrollableContainerLayoutView {
    lazy var networkView = AssetListChainView()
    lazy var networkContainerView: UIView = .create { [weak self] view in
        guard let self else { return }

        view.addSubview(networkView)

        networkView.snp.makeConstraints { make in
            make.leading.bottom.top.equalToSuperview()
        }
    }

    let titleView: UILabel = .create { view in
        view.apply(style: .boldTitle3Primary)
        view.textAlignment = .left
    }

    let mnemonicCardView = HiddenMnemonicCardView()

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(titleView, spacingAfter: 16)
        addArrangedSubview(mnemonicCardView)

        stackView.alignment = .fill
    }

    override func setupStyle() {
        super.setupStyle()

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    func showMnemonics(model: MnemonicCardView.Model) {
        mnemonicCardView.showMnemonic(model: model)
    }

    func showCover(model: HiddenMnemonicCardView.CoverModel) {
        mnemonicCardView.showCover(model: model)
    }

    func showNetwork(with viewModel: NetworkViewModel) {
        var subviews: [UIView] = []

        stackView.arrangedSubviews.forEach { view in
            subviews.append(view)
            view.removeFromSuperview()
        }

        addArrangedSubview(
            networkContainerView,
            spacingAfter: Constants.stackSpacing
        )

        networkView.bind(viewModel: viewModel)

        subviews.forEach { view in
            self.addArrangedSubview(
                view,
                spacingAfter: Constants.stackSpacing
            )
        }
    }
}

// MARK: Model

extension BackupMnemonicCardViewLayout {
    struct Model {
        var walletViewModel: DisplayWalletViewModel
        var networkViewModel: NetworkViewModel?
        var mnemonicCardState: HiddenMnemonicCardView.State
    }
}

// MARK: Constants

private extension BackupMnemonicCardViewLayout {
    enum Constants {
        static let itemsSpacing: CGFloat = 4
        static let stackSpacing: CGFloat = 16
        static let sectionContentInset = UIEdgeInsets(
            top: 0.0,
            left: 12.0,
            bottom: 14.0,
            right: 12.0
        )
    }
}
