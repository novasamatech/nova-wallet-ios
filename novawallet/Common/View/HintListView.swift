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

    func bind(texts: [String]) {
        if texts.count < hints.count {
            let hintsToRemove = hints.suffix(hints.count - texts.count)
            hints = Array(hints.prefix(texts.count))

            hintsToRemove.forEach { $0.removeFromSuperview() }
        } else if texts.count > hints.count {
            let addHintsCount = texts.count - hints.count
            let newHints = (0 ..< addHintsCount).map { _ in IconDetailsView.hint() }

            newHints.forEach { stackView.addArrangedSubview($0) }

            hints += newHints
        }

        for (text, hint) in zip(texts, hints) {
            hint.detailsLabel.text = text
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
