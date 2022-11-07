import UIKit
import MarkdownView

final class ReferendumFullDescriptionViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12, left: 16, bottom: 24, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let titleLabel: UILabel = .create {
        $0.textColor = R.color.colorWhite()
        $0.font = .boldTitle1
        $0.numberOfLines = 0
    }

    let markdownView = MarkdownView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.addArrangedSubview(markdownView)
        containerView.stackView.setCustomSpacing(16, after: titleLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func set(markdownText: String) {
        markdownView.loadFull(markdownText: markdownText)
    }

    func set(title: String) {
        titleLabel.text = title
    }
}
