import UIKit

final class ProcessStepView: UIView {
    let stepNumberView: BorderedLabelView = {
        let view = BorderedLabelView()
        view.backgroundView.applyFilledBackgroundStyle()
        view.backgroundView.fillColor = R.color.colorChipsBackground()!
        view.backgroundView.cornerRadius = 16.0
        view.titleLabel.textColor = R.color.colorTextSecondary()
        view.titleLabel.font = .regularBody
        view.titleLabel.textAlignment = .center
        return view
    }()

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .regularBody
        label.textColor = R.color.colorTextSecondary()
        label.numberOfLines = 0
        return label
    }()

    var spacing: CGFloat = 16.0 {
        didSet {
            descriptionLabel.snp.updateConstraints { make in
                make.leading.equalTo(stepNumberView.snp.trailing).offset(spacing)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        let stepViewHeight = 2 * stepNumberView.backgroundView.cornerRadius

        addSubview(stepNumberView)
        stepNumberView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(stepViewHeight)
        }

        addSubview(descriptionLabel)
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(1.0)
            make.trailing.equalToSuperview()
            make.leading.equalTo(stepNumberView.snp.trailing).offset(spacing)
            make.height.greaterThanOrEqualTo(stepNumberView.snp.height)
            make.bottom.equalToSuperview()
        }
    }
}
