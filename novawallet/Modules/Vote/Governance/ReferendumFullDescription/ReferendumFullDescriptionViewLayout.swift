import UIKit
import CDMarkdownKit

final class ReferendumFullDescriptionViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorTextPrimary()
        $0.font = .boldTitle1
        $0.numberOfLines = 0
    }

    let markdownView = MarkdownViewContainer(
        preferredWidth: UIScreen.main.bounds.width - 2 * UIConstants.horizontalInset
    )

    let activityIndicator: UIActivityIndicatorView = .create {
        $0.hidesWhenStopped = true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(markdownText: String) {
        activityIndicator.startAnimating()

        markdownView.load(from: markdownText) { [weak self] model in
            if model != nil {
                self?.activityIndicator.stopAnimating()
            }
        }
    }

    func set(title: String) {
        titleLabel.text = title
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.addArrangedSubview(markdownView)
        containerView.stackView.setCustomSpacing(16, after: titleLabel)

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
}
