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

    var style: Style? {
        didSet {
            applyStyleIfNeeded()
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

        applyStyleIfNeeded()
    }

    private func applyStyleIfNeeded() {
        guard let style = style else {
            return
        }

        for hint in hints {
            hint.stackView.alignment = style.itemAlignment
            hint.iconWidth = style.iconWidth
            hint.imageView.contentMode = style.iconContentMode
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

    func bind(viewModels: [ViewModel]) {
        updateHints(for: viewModels.count)

        for (viewModel, hint) in zip(viewModels, hints) {
            if let icon = viewModel.icon {
                hint.imageView.image = icon
            }

            hint.detailsLabel.attributedText = viewModel.attributedText
        }
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension HintListView {
    struct Style {
        let itemAlignment: UIStackView.Alignment
        let iconWidth: CGFloat
        let iconContentMode: UIView.ContentMode
    }

    struct ViewModel {
        let icon: UIImage?
        let attributedText: NSAttributedString
    }
}
