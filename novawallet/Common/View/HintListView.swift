import Foundation
import UIKit

class HintListView: UIView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .fill
        view.spacing = 8.0
        return view
    }()

    private var hints: [IconDetailsView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateHints(for newCount: Int) {
        if newCount < hints.count {
            let hintsToRemove = hints.suffix(hints.count - newCount)
            hints = Array(hints.prefix(newCount))

            hintsToRemove.forEach { $0.removeFromSuperview() }
        } else if newCount > hints.count {
            let addHintsCount = newCount - hints.count
            let newHints = (0 ..< addHintsCount).map { _ in IconDetailsView.hint() }

            newHints.forEach { stackView.addArrangedSubview($0) }

            hints += newHints
        }
    }

    func bind(texts: [String]) {
        updateHints(for: texts.count)

        for (text, hint) in zip(texts, hints) {
            hint.detailsLabel.text = text
        }

        setNeedsLayout()
    }

    func bind(attributedTexts: [NSAttributedString]) {
        updateHints(for: attributedTexts.count)

        for (text, hint) in zip(attributedTexts, hints) {
            hint.detailsLabel.attributedText = text
        }

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
