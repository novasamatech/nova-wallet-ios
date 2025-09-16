import UIKit
import UIKit_iOS

protocol ErrorStateViewDelegate: AnyObject {
    func didRetry(errorView: ErrorStateView)
}

class ErrorStateView: UIView {
    weak var delegate: ErrorStateViewDelegate?

    let iconImageView = UIImageView(image: R.image.iconLoadingError())

    let errorDescriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .regularFootnote
        label.textColor = R.color.colorTextSecondary()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    let retryButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(R.color.colorIconAccent(), for: .normal)
        return button
    }()

    lazy var stackView = UIStackView(arrangedSubviews: [iconImageView, errorDescriptionLabel, retryButton])

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        applyLocalization()
        retryButton.addTarget(self, action: #selector(handleRetryAction), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .center

        addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.top.greaterThanOrEqualToSuperview()
            $0.trailing.bottom.lessThanOrEqualToSuperview()
        }
    }

    private func applyLocalization() {
        let title = R.string(preferredLanguages: locale.rLanguages).localizable.commonRetry()
        retryButton.setTitle(title, for: .normal)
    }

    @objc
    func handleRetryAction() {
        delegate?.didRetry(errorView: self)
    }
}
