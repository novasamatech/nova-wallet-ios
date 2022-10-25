import UIKit

final class ReferendumVotingStatusView: UIView {
    let titleLabel: UILabel = .init(style: .title)
    let statusLabel: UILabel = .init(style: .positiveStatusLabel)

    let timeView: IconDetailsView = .create {
        $0.mode = .detailsIcon
        $0.detailsLabel.numberOfLines = 1
        $0.spacing = 5
        $0.iconWidth = 14.0
        $0.apply(style: .timeView)
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
                    titleLabel,
                    UIView(),
                    timeView
                ]),
                statusLabel
            ]
        )
        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
}

extension ReferendumVotingStatusView {
    struct Model {
        let status: Status
        let time: Time?
        let title: String?
    }

    struct Time: Equatable {
        let titleIcon: TitleIconViewModel
        let isUrgent: Bool
    }

    struct Status {
        let name: String
        let kind: StatusKind
    }

    enum StatusKind {
        case positive
        case negative
        case neutral

        init(infoKind: ReferendumInfoView.Model.StatusKind) {
            switch infoKind {
            case .positive:
                self = .positive
            case .negative:
                self = .negative
            case .neutral:
                self = .neutral
            }
        }
    }

    func bind(viewModel: Model) {
        titleLabel.text = viewModel.title
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

private extension UILabel.Style {
    static let positiveStatusLabel = UILabel.Style(
        textColor: R.color.colorGreen15CF37(),
        font: .boldTitle2
    )
    static let negativeStatusLabel = UILabel.Style(
        textColor: R.color.colorRedFF3A69(),
        font: .boldTitle2
    )
    static let neutralStatusLabel = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .boldTitle2
    )
    static let title = UILabel.Style.footnoteWhite64
}
