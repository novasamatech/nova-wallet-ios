import UIKit
import SoraUI

final class WalletAccountActionView: BaseActionControl {
    let backgroundView: RoundedView = {
        let roundedView = UIFactory.default.createRoundedBackgroundView()
        roundedView.applyCellBackgroundStyle()
        roundedView.isUserInteractionEnabled = false
        return roundedView
    }()

    var imageIndicator: ImageActionIndicator! {
        indicator as? ImageActionIndicator
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
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
        imageIndicator.image = R.image.iconSmallArrowDown()?.tinted(with: R.color.colorWhite48()!)
        indicator = imageIndicator
        indicator?.backgroundColor = .clear
        indicator?.isUserInteractionEnabled = false

        contentInsets = UIEdgeInsets(top: 9.0, left: 16.0, bottom: 9.0, right: 16.0)

        layoutType = .flexible
    }
}
