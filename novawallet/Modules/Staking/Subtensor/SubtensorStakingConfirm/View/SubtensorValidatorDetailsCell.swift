import UIKit
import UIKit_iOS

final class SubtensorValidatorDetailsView: SwapGenericInfoView<GenericPairValueView<IconDetailsView, UILabel>> {
    var nameView: IconDetailsView { valueView.fView }
    var apyLabel: UILabel { valueView.sView }

    private var iconViewModel: ImageViewModelProtocol?

    override func configure() {
        super.configure()

        valueView.makeVertical()
        valueView.stackView.alignment = .trailing
        valueView.spacing = 2

        nameView.mode = .iconDetails
        nameView.spacing = 8
        nameView.iconWidth = Constants.iconSize
        nameView.detailsLabel.apply(style: .footnotePrimary)
        nameView.detailsLabel.lineBreakMode = .byTruncatingMiddle

        apyLabel.apply(style: .caption1Positive)
        apyLabel.textAlignment = .right
    }

    func bind(viewModel: DisplayAddressViewModel) {
        iconViewModel?.cancel(on: nameView.imageView)
        iconViewModel = viewModel.imageViewModel

        nameView.imageView.image = nil
        viewModel.imageViewModel?.loadImage(
            on: nameView.imageView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )

        nameView.detailsLabel.lineBreakMode = viewModel.lineBreakMode
        nameView.detailsLabel.text = viewModel.name ?? viewModel.address
    }

    func bind(apy: String?) {
        apyLabel.text = apy
        apyLabel.isHidden = apy == nil
    }
}

private extension SubtensorValidatorDetailsView {
    enum Constants {
        static let iconSize: CGFloat = 20
    }
}

final class SubtensorValidatorDetailsCell: RowView<SubtensorValidatorDetailsView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleButton }
}
