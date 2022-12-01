import UIKit

final class TrackTagsView: UIView {
    let trackNameView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.apply(style: .track)
        $0.backgroundView.apply(style: .referendum)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
    }

    let numberLabel: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .track)
        $0.contentInsets = .init(top: 4, left: 8, bottom: 4, right: 8)
        $0.backgroundView.apply(style: .referendum)
        $0.titleLabel.numberOfLines = 1
    }

    private(set) var trackIconViewModel: ImageViewModelProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.hStack(
            spacing: 6,
            [
                trackNameView,
                numberLabel
            ]
        )
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension TrackTagsView: BindableView {
    struct Model {
        let titleIcon: ReferendumInfoView.Track?
        let referendumNumber: String?
    }

    func bind(viewModel: Model) {
        if let referendumNumber = viewModel.referendumNumber {
            numberLabel.isHidden = false
            numberLabel.titleLabel.text = referendumNumber
        } else {
            numberLabel.isHidden = true
        }

        trackIconViewModel?.cancel(on: trackNameView.iconDetailsView.imageView)
        trackIconViewModel = nil

        if let titleIcon = viewModel.titleIcon {
            trackNameView.isHidden = false
            trackNameView.iconDetailsView.detailsLabel.text = titleIcon.title

            trackIconViewModel = titleIcon.icon
            let size = trackNameView.iconDetailsView.iconWidth
            trackIconViewModel?.loadImage(
                on: trackNameView.iconDetailsView.imageView,
                targetSize: CGSize(width: size, height: size),
                animated: true
            )
        } else {
            trackNameView.isHidden = true
        }
    }
}
