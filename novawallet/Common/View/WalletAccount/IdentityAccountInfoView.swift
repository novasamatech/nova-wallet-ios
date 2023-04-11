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

        let knownAddressView = IdentityAccountViewFactory.setupWalletAccountView()
        knownAddressView.valueView.image = actionIcon

        contentView = knownAddressView

        return knownAddressView.titleView
    }

    private func setupUnknowAddressViewIfNeeded() -> UnknownAddressView {
        if let contentView = contentView as? UnknownAddressContentView {
            return contentView.titleView
        }

        let unknownAddressView = IdentityAccountViewFactory.setupUnknownAddressView()
        unknownAddressView.valueView.image = actionIcon

        contentView = unknownAddressView

        return unknownAddressView.titleView
    }
}

final class IdentityAccountContentView: UIView {
    private var internalView: UIView?

    var contentInsets = UIEdgeInsets(top: 5.0, left: 16.0, bottom: 5.0, right: 16.0) {
        didSet {
            internalView?.snp.updateConstraints { make in
                make.edges.equalToSuperview().inset(contentInsets)
            }
        }
    }

    convenience init() {
        let size = CGSize(width: 340.0, height: 48)
        let defaultFrame = CGRect(origin: .zero, size: size)
        self.init(frame: defaultFrame)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
    }

    private func setupWalletAccountViewIfNeeded() -> IdentityAccountView {
        if let internalView = internalView as? KnownAddressContentView {
            return internalView.titleView
        }

        clearInternalView()

        let knownAddressView = IdentityAccountViewFactory.setupWalletAccountView()

        addSubview(knownAddressView)

        internalView = knownAddressView

        setupInternalConstraints()

        return knownAddressView.titleView
    }

    private func setupUnknowAddressViewIfNeeded() -> UnknownAddressView {
        if let internalView = internalView as? UnknownAddressContentView {
            return internalView.titleView
        }

        clearInternalView()

        let unknownAddressView = IdentityAccountViewFactory.setupUnknownAddressView()

        addSubview(unknownAddressView)

        internalView = unknownAddressView

        setupInternalConstraints()

        return unknownAddressView.titleView
    }

    private func clearInternalView() {
        internalView?.removeFromSuperview()
        internalView = nil
    }

    private func setupInternalConstraints() {
        internalView?.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(contentInsets)
        }
    }
}

private enum IdentityAccountViewFactory {
    static func setupWalletAccountView() -> KnownAddressContentView {
        let knownAddressView = KnownAddressContentView()
        knownAddressView.isUserInteractionEnabled = false

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

        return knownAddressView
    }

    static func setupUnknownAddressView() -> UnknownAddressContentView {
        let unknownAddressView = UnknownAddressContentView()
        unknownAddressView.isUserInteractionEnabled = false

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

        return unknownAddressView
    }
}
