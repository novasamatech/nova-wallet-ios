import UIKit

final class VotingProgressView: UIView {
    let thresholdView: IconDetailsView = .create {
        $0.detailsLabel.apply(style: .referendaTimeView)
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
        let ayeProgress: String
        let passProgress: String
        let nayProgress: String
        let thresholdModel: ThresholdModel?
        let progress: Decimal
    }

    struct ThresholdModel {
        let image: UIImage?
        let text: String
        let value: Decimal
    }

    func bind(viewModel: Model) {
        slider.bind(viewModel: .init(
            thumbValue: viewModel.thresholdModel?.value,
            value: viewModel.progress
        ))

        ayeProgressLabel.text = viewModel.ayeProgress
        passProgressLabel.text = viewModel.passProgress
        nayProgressLabel.text = viewModel.nayProgress

        viewModel.thresholdModel.map {
            thresholdView.imageView.image = $0.image
            thresholdView.detailsLabel.text = $0.text
        }
    }
}

extension UILabel.Style {
    static let referendaTimeView = UILabel.Style(
        textColor: R.color.colorWhite64(),
        font: .caption1
    )
}
