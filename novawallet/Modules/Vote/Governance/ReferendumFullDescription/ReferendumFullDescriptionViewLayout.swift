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
        markdownView.load(
            markdown: markdownText,
            css: css(),
            plugins: plugins()
        )
    }

    func set(title: String) {
        titleLabel.text = title
    }

    private func plugins() -> [String]? {
        [
            URL(string: "https://cdnjs.cloudflare.com/ajax/libs/markdown-it-footnote/3.0.3/markdown-it-footnote.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sub@1.0.0/index.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-sup@1.0.0/index.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-ins@3.0.1/dist/markdown-it-ins.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-mark@3.0.1/dist/markdown-it-mark.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-container@3.0.0/dist/markdown-it-container.min.js"),
            URL(string: "https://cdn.jsdelivr.net/npm/markdown-it-deflist@2.1.0/dist/markdown-it-deflist.min.js")
        ].compactMap { $0 }
            .compactMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    private func css() -> String? {
        guard let color = R.color.colorNovaBlue()?.hexRGB else {
            return nil
        }
        return "a { color: \(color); }"
    }
}
