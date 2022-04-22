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

    var contentView: WalletAccountView! {
        title as? WalletAccountView
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
        contentView.bind(viewModel: viewModel)

        invalidateLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        backgroundView.frame = bounds
    }

    private func configure() {
        backgroundColor = .clear

        addSubview(backgroundView)

        let imageIndicator = ImageActionIndicator()
        imageIndicator.image = R.image.iconSmallArrowDown()?.tinted(with: R.color.colorWhite48()!)
        indicator = imageIndicator
        indicator?.backgroundColor = .clear
        indicator?.isUserInteractionEnabled = false

        title = WalletAccountView()
        title?.isUserInteractionEnabled = false

        contentInsets = UIEdgeInsets(top: 9.0, left: 16.0, bottom: 9.0, right: 16.0)

        layoutType = .flexible
    }
}
