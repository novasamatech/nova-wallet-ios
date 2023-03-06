import UIKit

final class GovernanceSelectableTrackView: UIView {
    let contentView = IconDetailsGenericView<BorderedIconLabelView>()

    var checkmarkView: UIImageView {
        contentView.imageView
    }

    var trackIconView: UIImageView {
        contentView.detailsView.iconDetailsView.imageView
    }

    var trackLabel: UILabel {
        contentView.detailsView.iconDetailsView.detailsLabel
    }

    private var trackIconViewModel: ImageViewModelProtocol?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SelectableViewModel<ReferendumInfoView.Track>) {
        if viewModel.selectable {
            checkmarkView.image = R.image.iconCheckbox()
        } else {
            checkmarkView.image = R.image.iconCheckboxEmpty()
        }

        trackLabel.text = viewModel.underlyingViewModel.title

        trackIconViewModel?.cancel(on: trackIconView)

        let iconSize = contentView.detailsView.iconDetailsView.iconWidth
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

    private func setupLayout() {
        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview()
        }
    }

    private func applyStyle() {
        contentView.iconWidth = 24
        contentView.mode = .iconDetails
        contentView.spacing = 12

        contentView.detailsView.iconDetailsView.spacing = 6
        contentView.detailsView.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        contentView.detailsView.iconDetailsView.detailsLabel.numberOfLines = 1
        contentView.detailsView.apply(style: .track)
    }
}
