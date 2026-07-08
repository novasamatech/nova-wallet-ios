import UIKit
import UIKit_iOS

private enum WalletManageTableViewCellConstants {
    static let favouriteButtonSize: CGFloat = 28
    static let favouriteButtonContentSpacing: CGFloat = 8
    // Pulls the wallet content slightly closer to the delete control in edit
    // mode so row alignment matches the prod (no-favourite-button) layout.
    // Empirically tuned against the prod build.
    static let reorderingContentLeadingOffset: CGFloat = -11
}

final class WalletManageTableViewCell<V: WalletViewProtocol>: WalletsListTableViewCell<V, UIImageView> {
    private typealias Constants = WalletManageTableViewCellConstants

    private lazy var reorderingAnimator = BlockViewAnimator()

    let favouriteButton: UIButton = {
        let button = UIButton(type: .custom)
        let normalIcon = UIImage(systemName: "star")?.withTintColor(
            R.color.colorTextSecondary() ?? .gray,
            renderingMode: .alwaysOriginal
        )
        let selectedIcon = UIImage(systemName: "star.fill")?.withTintColor(
            R.color.colorIconAccent() ?? .systemYellow,
            renderingMode: .alwaysOriginal
        )
        button.setImage(normalIcon, for: .normal)
        button.setImage(selectedIcon, for: .selected)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    var onFavouriteTapped: (() -> Void)?

    var disclosureIndicatorView: UIImageView { contentDisplayView.valueView }

    override func setupStyle() {
        super.setupStyle()

        let icon = R.image.iconSmallArrow()?.tinted(with: R.color.colorTextSecondary()!)
        disclosureIndicatorView.image = icon
        disclosureIndicatorView.setContentCompressionResistancePriority(.required, for: .horizontal)
        disclosureIndicatorView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    override func setupLayout() {
        contentView.addSubview(favouriteButton)
        favouriteButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalToSuperview()
            make.height.equalTo(Constants.favouriteButtonSize)
            make.width.equalTo(Constants.favouriteButtonSize)
        }

        contentView.addSubview(contentDisplayView)
        contentDisplayView.snp.makeConstraints { make in
            make.leading.equalTo(favouriteButton.snp.trailing).offset(Constants.favouriteButtonContentSpacing)
            make.top.bottom.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        favouriteButton.addTarget(self, action: #selector(handleFavouriteTap), for: .touchUpInside)
    }

    private func updateContentLeading(reordering: Bool) {
        contentDisplayView.snp.updateConstraints { make in
            let offset = reordering
                ? Constants.reorderingContentLeadingOffset
                : Constants.favouriteButtonContentSpacing
            make.leading.equalTo(favouriteButton.snp.trailing).offset(offset)
        }
    }

    @objc private func handleFavouriteTap() {
        onFavouriteTapped?()
    }

    override func bind(viewModel: WalletsListViewModel) {
        super.bind(viewModel: viewModel)
        favouriteButton.isSelected = viewModel.isFavourite
    }

    func setReordering(_ reordering: Bool, animated: Bool) {
        favouriteButton.snp.updateConstraints { make in
            make.width.equalTo(reordering ? 0 : Constants.favouriteButtonSize)
        }
        updateContentLeading(reordering: reordering)

        let closure = {
            self.disclosureIndicatorView.alpha = reordering ? 0.0 : 1.0
            self.favouriteButton.alpha = reordering ? 0.0 : 1.0
            self.contentView.layoutIfNeeded()
        }

        if animated {
            reorderingAnimator.animate(block: closure, completionBlock: nil)
        } else {
            closure()
        }

        if reordering {
            recolorReorderControl(R.color.colorIconPrimary()!)
        }
    }
}
