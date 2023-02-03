import UIKit

final class GovernanceSelectableTrackView: IconDetailsGenericView<BorderedIconLabelView> {
    var checkmarkView: UIImageView {
        imageView
    }

    var trackIconView: UIImageView {
        detailsView.iconDetailsView.imageView
    }

    var trackLabel: UILabel {
        detailsView.iconDetailsView.detailsLabel
    }

    private var trackIconViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyStyle()
    }

    func bind(viewModel: SelectableViewModel<ReferendumInfoView.Track>) {
        if viewModel.selectable {
            checkmarkView.image = R.image.iconCheckbox()
        } else {
            checkmarkView.image = R.image.iconCheckboxEmpty()
        }

        trackLabel.text = viewModel.underlyingViewModel.title

        trackIconViewModel?.cancel(on: trackIconView)

        let iconSize = detailsView.iconDetailsView.iconWidth
        let imageSettings = ImageViewModelSettings(
            targetSize: CGSize(width: iconSize, height: iconSize),
            cornerRadius: nil,
            tintColor: BorderedIconLabelView.Style.track.text.textColor
        )

        trackIconViewModel = viewModel.underlyingViewModel.icon

        trackIconViewModel?.loadImage(
            on: trackIconView,
            settings: imageSettings,
            animated: true
        )
    }

    private func applyStyle() {
        iconWidth = 24
        mode = .iconDetails
        spacing = 12

        detailsView.iconDetailsView.spacing = 6
        detailsView.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        detailsView.iconDetailsView.detailsLabel.numberOfLines = 1
        detailsView.apply(style: .track)
    }
}
