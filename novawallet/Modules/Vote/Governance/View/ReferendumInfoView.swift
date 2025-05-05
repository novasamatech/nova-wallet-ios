import UIKit
import UIKit_iOS

final class ReferendumInfoView: UIView {
    let statusLabel: UILabel = .init(style: .neutralStatusLabel)

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.numberOfLines = 1
        $0.spacing = 5
        $0.apply(style: .timeView)
    }

    let titleLabel: UILabel = .init(style: .title)

    let trackNameView: BorderedIconLabelView = .create {
        $0.iconDetailsView.spacing = 6
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.iconDetailsView.detailsLabel.numberOfLines = 1
        $0.apply(style: .track)
    }

    let numberLabel: BorderedLabelView = .create {
        $0.titleLabel.apply(style: .track)
        $0.contentInsets = .init(top: 4, left: 6, bottom: 4, right: 8)
        $0.backgroundView.apply(style: .referendum)
        $0.titleLabel.numberOfLines = 1
    }

    private var trackImageViewModel: ImageViewModelProtocol?

    lazy var trackInformation: UIStackView = UIView.hStack(
        spacing: Constants.trackInformationHorizontalSpace,
        [
            trackNameView,
            numberLabel,
            UIView()
        ]
    )

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
            spacing: Constants.verticalSpace,
            [
                UIView.hStack([
                    statusLabel,
                    UIView(),
                    timeView
                ]),
                titleLabel,
                trackInformation
            ]
        )

        content.setCustomSpacing(Constants.afterTitleLabelVerticalSpace, after: titleLabel)

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        trackInformation.snp.makeConstraints {
            $0.height.equalTo(Constants.trackInformationHeight)
        }
    }
}

extension ReferendumInfoView {
    enum Constants {
        static let verticalSpace: CGFloat = 8
        static let afterTitleLabelVerticalSpace: CGFloat = 12
        static let trackInformationHeight: CGFloat = 22
        static let trackInformationHorizontalSpace: CGFloat = 6
    }
}

extension ReferendumInfoView {
    struct Model {
        let status: Status
        var time: Time?
        let title: String?
        let track: Track?
        let referendumNumber: String?
    }

    struct Time: Equatable {
        let titleIcon: TitleIconViewModel
        let isUrgent: Bool
    }

    struct Track {
        let title: String
        let icon: ImageViewModelProtocol?
    }

    struct Status {
        let name: String
        let kind: StatusKind
    }

    enum StatusKind {
        case positive
        case negative
        case neutral
    }

    func bind(viewModel: Model) {
        trackImageViewModel?.cancel(on: trackNameView.iconDetailsView.imageView)
        trackImageViewModel = viewModel.track?.icon

        if let track = viewModel.track {
            trackNameView.isHidden = false

            trackNameView.iconDetailsView.detailsLabel.text = track.title

            let iconSize = trackNameView.iconDetailsView.iconWidth
            let imageSettings = ImageViewModelSettings(
                targetSize: CGSize(width: iconSize, height: iconSize),
                cornerRadius: nil,
                tintColor: UILabel.Style.track.textColor
            )

            track.icon?.loadImage(
                on: trackNameView.iconDetailsView.imageView,
                settings: imageSettings,
                animated: true
            )
        } else {
            trackNameView.isHidden = true
        }

        numberLabel.isHidden = viewModel.referendumNumber == nil

        titleLabel.text = viewModel.title

        numberLabel.titleLabel.text = viewModel.referendumNumber
        statusLabel.text = viewModel.status.name
        bind(timeModel: viewModel.time)

        switch viewModel.status.kind {
        case .positive:
            statusLabel.apply(style: .positiveStatusLabel)
        case .negative:
            statusLabel.apply(style: .negativeStatusLabel)
        case .neutral:
            statusLabel.apply(style: .neutralStatusLabel)
        }
    }

    func bind(timeModel: Time?) {
        if let time = timeModel {
            timeView.bind(viewModel: time.titleIcon)
            timeView.apply(style: time.isUrgent ? .activeTimeView : .timeView)
        } else {
            timeView.bind(viewModel: nil)
        }
    }
}

extension IconDetailsView.Style {
    static let timeView = IconDetailsView.Style(
        tintColor: R.color.colorTextSecondary()!,
        font: .caption1
    )
    static let activeTimeView = IconDetailsView.Style(
        tintColor: R.color.colorTextWarning()!,
        font: .caption1
    )

    static let chips = IconDetailsView.Style(
        tintColor: R.color.colorIconChip()!,
        font: .semiBoldCaps2
    )
}

private extension UILabel.Style {
    static let positiveStatusLabel = UILabel.Style(
        textColor: R.color.colorTextPositive(),
        font: .semiBoldCaps1
    )
    static let neutralStatusLabel = UILabel.Style(
        textColor: R.color.colorTextSecondary(),
        font: .semiBoldCaps1
    )
    static let negativeStatusLabel = UILabel.Style(
        textColor: R.color.colorTextNegative(),
        font: .semiBoldCaps1
    )
    static let title = UILabel.Style(
        textColor: R.color.colorTextPrimary(),
        font: .regularSubheadline
    )
}

extension UILabel.Style {
    static let track = UILabel.Style(
        textColor: R.color.colorChipText(),
        font: .semiBoldCaps1
    )
}

extension RoundedView.Style {
    static let referendum = RoundedView.Style.roundedChips(radius: 7)
}
