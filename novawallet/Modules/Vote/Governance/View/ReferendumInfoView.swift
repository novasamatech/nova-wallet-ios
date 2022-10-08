import UIKit
import SoraUI

final class ReferendumInfoView: UIView {
    let statusLabel: UILabel = .init(style: .neutralStatusLabel)

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.apply(style: .timeViewLabel)
        $0.detailsLabel.numberOfLines = 1
        $0.spacing = 5
    }

    let titleLabel: UILabel = .init(style: .title)

    let trackNameView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.apply(style: .track)
        $0.backgroundView.apply(style: .referendum)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
    }

    let numberLabel: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .track)
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.backgroundView.apply(style: .referendum)
        $0.titleLabel.numberOfLines = 1
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let content = UIView.vStack(
            spacing: 8,
            [
                UIView.hStack([
                    statusLabel,
                    UIView(),
                    timeView
                ]),
                titleLabel,
                UIView.hStack(
                    spacing: 6,
                    [
                        trackNameView,
                        numberLabel,
                        UIView()
                    ]
                )
            ]
        )
        content.setCustomSpacing(12, after: titleLabel)
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension ReferendumInfoView {
    struct Model {
        let status: String
        let time: String?
        let timeImage: UIImage?
        let title: String
        let trackName: String
        let trackImage: UIImage?
        let number: String
    }

    func bind(viewModel: Model) {
        timeView.detailsLabel.text = viewModel.time
        timeView.imageView.image = viewModel.timeImage
        titleLabel.text = viewModel.title
        trackNameView.iconDetailsView.imageView.image = viewModel.trackImage
        trackNameView.iconDetailsView.detailsLabel.text = viewModel.trackName
        numberLabel.titleLabel.text = viewModel.number
        statusLabel.text = viewModel.status
    }
}

extension UILabel.Style {
    static let positiveStatusLabel = UILabel.Style(
        textColor: R.color.colorDarkGreen(),
        font: .semiBoldCaps1
    )
    static let neutralStatusLabel = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .semiBoldCaps1
    )
    static let negativeStatusLabel = UILabel.Style(
        textColor: R.color.colorRedFF3A69(),
        font: .semiBoldCaps1
    )
    static let timeViewLabel = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
    static let activeTimeViewLabel = UILabel.Style(
        textColor: R.color.colorDarkYellow(),
        font: .caption1
    )

    static let title = UILabel.Style(
        textColor: .white,
        font: .regularSubheadline
    )

    static let track = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .semiBoldCaps1
    )
}

extension RoundedView.Style {
    static let referendum = RoundedView.Style(
        fillColor: R.color.colorWhite8()!,
        highlightedFillColor: R.color.colorWhite8()!,
        cornerRadius: 8
    )
}
