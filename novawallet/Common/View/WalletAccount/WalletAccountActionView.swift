import UIKit
import SoraUI

final class WalletAccountActionView: BaseActionControl {
    static let preferredHeight = 56.0

    let backgroundView: RoundedView = {
        let roundedView = UIFactory.default.createRoundedBackgroundView()
        roundedView.applyCellBackgroundStyle()
        roundedView.isUserInteractionEnabled = false
        return roundedView
    }()

    var imageIndicator: ImageActionIndicator! {
        indicator as? ImageActionIndicator
    }

    convenience init() {
        let defaultFrame = CGRect(origin: .zero, size: CGSize(width: 340.0, height: 56.0))
        self.init(frame: defaultFrame)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    var shouldEnableAction: Bool = true {
        didSet {
            updateActionState()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = bounds
    }

    private func setupWalletAccountViewIfNeeded() -> WalletAccountView {
        if let walletAccountView = title as? WalletAccountView {
            return walletAccountView
        }

        let walletAccountView = WalletAccountView()
        walletAccountView.isUserInteractionEnabled = false
        title = walletAccountView

        return walletAccountView
    }

    private func setupUnknowAddressViewIfNeeded() -> UnknownAddressView {
        if let unknownAddressView = title as? UnknownAddressView {
            return unknownAddressView
        }

        let unknownAddressView = UnknownAddressView()
        unknownAddressView.isUserInteractionEnabled = false
        title = unknownAddressView

        return unknownAddressView
    }

    private func configure() {
        backgroundColor = .clear

        addSubview(backgroundView)

        let imageIndicator = ImageActionIndicator()
        indicator = imageIndicator
        indicator?.backgroundColor = .clear
        indicator?.isUserInteractionEnabled = false

        contentInsets = UIEdgeInsets(top: 9.0, left: 16.0, bottom: 9.0, right: 16.0)

        layoutType = .flexible

        updateActionState()
    }

    private func updateActionState() {
        isUserInteractionEnabled = shouldEnableAction

        imageIndicator.image = shouldEnableAction ? R.image.iconSmallArrowDown()?.tinted(
            with: R.color.colorWhite48()!
        ) : nil
    }
}
