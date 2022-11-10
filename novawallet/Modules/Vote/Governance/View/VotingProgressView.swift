import UIKit

final class VotingProgressView: UIView {
    let thresholdView: IconDetailsView = .create {
        $0.detailsLabel.apply(style: .referendaTimeView)
        $0.imageView.contentMode = .scaleAspectFit
        $0.iconWidth = 14
        $0.spacing = 5
    }

    let slider: SegmentedSliderView = .create {
        $0.apply(style: .governance)
    }

    let ayeProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .left)
    let passProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .center)
    let nayProgressLabel: UILabel = .init(style: .referendaTimeView, textAlignment: .right)

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
                thresholdView,
                slider,
                UIView.hStack(
                    distribution: .fillEqually,
                    [
                        ayeProgressLabel,
                        passProgressLabel,
                        nayProgressLabel
                    ]
                )
            ]
        )

        addSubview(content)
        content.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Constants.contentInsets)
        }
    }
}

extension VotingProgressView {
    enum Constants {
        static let verticalSpace: CGFloat = 6
        static let contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)
    }
}

extension VotingProgressView: BindableView {
    struct Model {
        let support: SupportModel?
        let approval: ApprovalModel
    }

    struct SupportModel {
        let titleIcon: TitleIconViewModel
        let completed: Bool
    }

    struct ApprovalModel {
        let passThreshold: Decimal
        let ayeProgress: Decimal?
        let ayeMessage: String
        let passMessage: String
        let nayMessage: String
    }

    func bind(viewModel: Model) {
        slider.bind(viewModel: .init(
            thumbProgress: viewModel.approval.passThreshold,
            value: viewModel.approval.ayeProgress
        ))

        ayeProgressLabel.text = viewModel.approval.ayeMessage
        passProgressLabel.text = viewModel.approval.passMessage
        nayProgressLabel.text = viewModel.approval.nayMessage

        if let support = viewModel.support, !support.completed {
            thresholdView.isHidden = false
            thresholdView.bind(viewModel: support.titleIcon)
        } else {
            thresholdView.isHidden = true
        }
    }
}

extension UILabel.Style {
    static let referendaTimeView = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
