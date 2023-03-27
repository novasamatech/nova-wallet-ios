import UIKit

private typealias KnownAddressContentView = GenericTitleValueView<IdentityAccountView, UIImageView>
private typealias UnknownAddressContentView = GenericTitleValueView<UnknownAddressView, UIImageView>

final class IdentityAccountInfoView: RowView<GenericTitleValueView<UIView, UIImageView>> {
    static let preferredHeight = 56.0

    var actionIcon: UIImage? = R.image.iconActionIndicator() {
        didSet {
            if let knownAddressView = contentView as? KnownAddressContentView {
                knownAddressView.valueView.image = actionIcon
            } else if let unknownAddressView = contentView as? UnknownAddressContentView {
                unknownAddressView.valueView.image = actionIcon
            }
        }
    }

    convenience init() {
        let size = CGSize(width: 340.0, height: Self.preferredHeight)
        let defaultFrame = CGRect(origin: .zero, size: size)
        self.init(frame: defaultFrame)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        configureStyle()
    }

    private func configureStyle() {
        roundedBackgroundView.applyFilledBackgroundStyle()
        roundedBackgroundView.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView.roundingCorners = .allCorners
        roundedBackgroundView.cornerRadius = 12.0
        borderView.borderType = []

        preferredHeight = Self.preferredHeight

        contentInsets = UIEdgeInsets(top: 9.0, left: 16.0, bottom: 9.0, right: 16.0)
    }

    func bind(viewModel: DisplayAddressViewModel) {
        if viewModel.name != nil {
            setupWalletAccountViewIfNeeded().bind(viewModel: viewModel)
        } else {
            setupUnknowAddressViewIfNeeded().bind(
                address: viewModel.address,
                iconViewModel: viewModel.imageViewModel
            )
        }

        invalidateLayout()
    }

    private func setupWalletAccountViewIfNeeded() -> IdentityAccountView {
        if let contentView = contentView as? KnownAddressContentView {
            return contentView.titleView
        }

        let knownAddressView = KnownAddressContentView()
        knownAddressView.isUserInteractionEnabled = false
        knownAddressView.valueView.image = actionIcon

        knownAddressView.titleView.nameLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        knownAddressView.titleView.addressLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        knownAddressView.titleView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        knownAddressView.valueView.setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )

        contentView = knownAddressView

        return knownAddressView.titleView
    }

    private func setupUnknowAddressViewIfNeeded() -> UnknownAddressView {
        if let contentView = contentView as? UnknownAddressContentView {
            return contentView.titleView
        }

        let unknownAddressView = UnknownAddressContentView()
        unknownAddressView.isUserInteractionEnabled = false
        unknownAddressView.valueView.image = actionIcon

        unknownAddressView.titleView.addressLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        unknownAddressView.titleView.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        unknownAddressView.valueView.setContentCompressionResistancePriority(
            .defaultHigh,
            for: .horizontal
        )

        contentView = unknownAddressView

        return unknownAddressView.titleView
    }
}
