import UIKit

private typealias KnownAddressContentView = GenericTitleValueView<WalletAccountView, UIImageView>
private typealias UnknownAddressContentView = GenericTitleValueView<UnknownAddressView, UIImageView>

final class WalletAccountInfoView: RowView<GenericTitleValueView<UIView, UIImageView>> {
    static let preferredHeight = 56.0

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
        roundedBackgroundView.fillColor = R.color.colorWhite8()!
        roundedBackgroundView.roundingCorners = .allCorners
        roundedBackgroundView.cornerRadius = 12.0
        borderView.borderType = []

        preferredHeight = Self.preferredHeight

        contentInsets = UIEdgeInsets(top: 9.0, left: 16.0, bottom: 9.0, right: 16.0)
    }

    func bind(viewModel: WalletAccountViewModel) {
        if viewModel.walletName != nil {
            setupWalletAccountViewIfNeeded().bind(viewModel: viewModel)
        } else {
            setupUnknowAddressViewIfNeeded().bind(
                address: viewModel.address,
                iconViewModel: viewModel.addressIcon
            )
        }

        invalidateLayout()
    }

    private func setupWalletAccountViewIfNeeded() -> WalletAccountView {
        if let contentView = contentView as? KnownAddressContentView {
            return contentView.titleView
        }

        let knownAddressView = KnownAddressContentView()
        knownAddressView.isUserInteractionEnabled = false
        knownAddressView.valueView.image = R.image.iconActionIndicator()

        knownAddressView.titleView.walletLabel.setContentCompressionResistancePriority(
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
        unknownAddressView.valueView.image = R.image.iconActionIndicator()

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
