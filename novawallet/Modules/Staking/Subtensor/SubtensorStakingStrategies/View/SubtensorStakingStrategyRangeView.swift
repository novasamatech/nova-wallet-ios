import SnapKit
import UIKit

final class SubtensorStakingStrategyRangeView: UIView {
    private let trackView: UIView = .create { view in
        view.backgroundColor = UIColor.white.withAlphaComponent(Constants.trackAlpha)
        view.layer.cornerRadius = Constants.trackHeight / 2
    }

    private let fillView: UIView = .create { view in
        view.layer.cornerRadius = Constants.trackHeight / 2
    }

    private let lowerLabel: UILabel = .create { view in
        view.font = .caption1
        view.textColor = R.color.colorTextSecondary()
    }

    private let periodLabel: UILabel = .create { view in
        view.font = .caption1
        view.textColor = R.color.colorTextSecondary()
        view.textAlignment = .center
    }

    private let upperLabel: UILabel = .create { view in
        view.font = .caption1
        view.textColor = R.color.colorTextSecondary()
        view.textAlignment = .right
    }

    private var fillWidthConstraint: Constraint?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: SubtensorStakingStrategyRangeViewModel) {
        lowerLabel.text = viewModel.lowerTitle
        periodLabel.text = viewModel.periodTitle
        upperLabel.text = viewModel.upperTitle

        fillWidthConstraint?.deactivate()

        let widthMultiplier: CGFloat

        switch viewModel.style {
        case .fixed:
            widthMultiplier = 0
            fillView.backgroundColor = UIColor.white.withAlphaComponent(Constants.trackAlpha)
        case .balanced:
            widthMultiplier = Constants.balancedWidthMultiplier
            fillView.backgroundColor = R.color.colorTextPositive()
        case .higherUpside:
            widthMultiplier = 1
            fillView.backgroundColor = R.color.colorTextWarning()
        }

        fillView.snp.remakeConstraints { make in
            make.center.equalTo(trackView)
            make.height.equalTo(Constants.trackHeight)

            if viewModel.style == .fixed {
                fillWidthConstraint = make.width.equalTo(Constants.trackHeight).constraint
            } else {
                fillWidthConstraint = make.width.equalTo(trackView.snp.width)
                    .multipliedBy(widthMultiplier)
                    .constraint
            }
        }
    }
}

private extension SubtensorStakingStrategyRangeView {
    func setupLayout() {
        addSubview(trackView)
        trackView.addSubview(fillView)
        addSubview(lowerLabel)
        addSubview(periodLabel)
        addSubview(upperLabel)

        trackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.trackHeight)
        }

        lowerLabel.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(trackView.snp.bottom).offset(Constants.labelsTopOffset)
        }

        periodLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(lowerLabel)
        }

        upperLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(lowerLabel)
        }
    }
}

private extension SubtensorStakingStrategyRangeView {
    enum Constants {
        static let trackHeight: CGFloat = 4
        static let trackAlpha: CGFloat = 0.16
        static let labelsTopOffset: CGFloat = 6
        static let balancedWidthMultiplier: CGFloat = 16.0 / 60.0
    }
}
