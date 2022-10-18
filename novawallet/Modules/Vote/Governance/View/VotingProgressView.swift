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
            spacing: 6,
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
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0))
        }
    }
}

extension VotingProgressView {
    struct Model {
        let support: TitleIconViewModel?
        let approval: ApprovalModel
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

        thresholdView.bind(viewModel: viewModel.support)
        thresholdView.isHidden = viewModel.support == nil
    }
}

extension UILabel.Style {
    static let referendaTimeView = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
