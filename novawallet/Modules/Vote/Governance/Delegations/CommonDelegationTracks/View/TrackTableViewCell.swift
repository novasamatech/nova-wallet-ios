import UIKit

final class TrackTableViewCell: UITableViewCell {
    let trackView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
        $0.apply(style: .track)
    }

    let valueView: MultiValueView = .create {
        $0.apply(style: .rowContrasted)
    }

    lazy var view = GenericTitleValueView<BorderedIconLabelView, MultiValueView>(
        titleView: trackView,
        valueView: valueView
    )

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        contentView.addSubview(view)
        view.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: 24, bottom: 14, right: 0))
        }
    }
}

extension TrackTableViewCell {
    struct Model {
        let track: ReferendumInfoView.Track
        let details: MultiValueView.Model?
    }

    func bind(viewModel: Model) {
        let iconSize = trackView.iconDetailsView.iconWidth
        let imageSettings = ImageViewModelSettings(
            targetSize: CGSize(width: iconSize, height: iconSize),
            cornerRadius: nil,
            tintColor: BorderedIconLabelView.Style.track.text.textColor
        )

        viewModel.track.icon?.loadImage(
            on: trackView.iconDetailsView.imageView,
            settings: imageSettings,
            animated: true
        )

        valueView.bindOrHide(viewModel: viewModel.details)
    }
}
