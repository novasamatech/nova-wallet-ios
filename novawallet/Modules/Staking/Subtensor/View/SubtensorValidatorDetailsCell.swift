import UIKit
import UIKit_iOS

final class SubtensorValidatorDetailsValueView: GenericPairValueView<IconDetailsView, UILabel> {
    private var nameView: IconDetailsView { fView }
    private var apyLabel: UILabel { sView }

    private var iconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        stackView.alignment = .trailing

        nameView.mode = .iconDetails
        nameView.spacing = Constants.iconSpacing
        nameView.iconWidth = Constants.iconSize
        nameView.detailsLabel.apply(style: .footnotePrimary)
        nameView.snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.nameLineHeight) }

        apyLabel.apply(style: .caption1Positive)
        apyLabel.textAlignment = .right
        apyLabel.snp.makeConstraints { $0.height.greaterThanOrEqualTo(Constants.apyLineHeight) }
    }

    func bind(viewModel: DisplayAddressViewModel) {
        bind(title: viewModel.name ?? viewModel.address)

        iconViewModel = viewModel.imageViewModel
        nameView.hidesIcon = false
        nameView.detailsLabel.lineBreakMode = viewModel.lineBreakMode
        viewModel.imageViewModel?.loadImage(
            on: nameView.imageView,
            targetSize: CGSize(width: Constants.iconSize, height: Constants.iconSize),
            animated: true
        )
    }

    func bind(title: String?) {
        iconViewModel?.cancel(on: nameView.imageView)
        iconViewModel = nil

        nameView.imageView.image = nil
        nameView.hidesIcon = true
        nameView.detailsLabel.lineBreakMode = .byTruncatingTail
        nameView.detailsLabel.text = title
    }

    func bind(apy: String?) {
        apyLabel.text = apy
        apyLabel.isHidden = apy == nil
    }
}

private extension SubtensorValidatorDetailsValueView {
    enum Constants {
        static let iconSize: CGFloat = 18
        static let iconSpacing: CGFloat = 6
        static let nameLineHeight: CGFloat = 18
        static let apyLineHeight: CGFloat = 16
    }
}

final class SubtensorValidatorDetailsView: SwapGenericInfoView<SubtensorValidatorDetailsValueView> {
    func bind(viewModel: DisplayAddressViewModel) {
        valueView.bind(viewModel: viewModel)
    }

    func bind(apy: String?) {
        valueView.bind(apy: apy)
    }
}

final class SubtensorValidatorDetailsCell: RowView<SubtensorValidatorDetailsView>, StackTableViewCellProtocol {
    var titleButton: RoundedButton { rowContentView.titleButton }
}
