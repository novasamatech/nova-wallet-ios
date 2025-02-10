import Foundation
import UIKit

class ExtendedPageControl: UIControl {
    private var dots: [UIView] = []

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Constants.spacing
        return stack
    }()

    var numberOfPages: Int = 0 {
        didSet {
            setupDots()
        }
    }

    var currentPage: Int = 0 {
        didSet {
            updateDots(animated: true)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
}

// MARK: Private

private extension ExtendedPageControl {
    func setupView() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func setupDots() {
        dots.forEach { $0.removeFromSuperview() }
        dots.removeAll()

        for pageIndex in 0 ..< numberOfPages {
            let dot = createDot()

            stackView.addArrangedSubview(dot)

            let width = pageIndex == currentPage
                ? Constants.extendedDotWidth
                : Constants.dotSize

            dot.snp.makeConstraints { make in
                make.height.equalTo(Constants.dotSize)
                make.width.equalTo(width)
            }

            dots.append(dot)
        }

        updateDots(animated: false)
    }

    func createDot() -> UIView {
        let dot = UIView()
        dot.backgroundColor = .white
        dot.layer.cornerRadius = Constants.dotSize / 2
        dot.layer.masksToBounds = true

        return dot
    }

    func updateDots(animated: Bool) {
        guard currentPage < dots.count else { return }

        let duration = animated ? Constants.animationDuration : .zero

        UIView.animate(withDuration: duration) { [weak self] in
            guard let self else { return }

            dots.enumerated().forEach { index, dot in
                if index == self.currentPage {
                    dot.snp.updateConstraints { make in
                        make.width.equalTo(Constants.extendedDotWidth)
                    }
                    dot.backgroundColor = R.color.colorIconChip()
                } else {
                    dot.snp.updateConstraints { make in
                        make.width.equalTo(Constants.dotSize)
                    }
                    dot.backgroundColor = R.color.colorIconInactive()
                }
            }

            layoutIfNeeded()
        }
    }
}

// MARK: Constants

private extension ExtendedPageControl {
    enum Constants {
        static let animationDuration: CGFloat = 0.3
        static let dotSize: CGFloat = 6.0
        static let extendedDotWidth: CGFloat = 20
        static let spacing: CGFloat = 6
    }
}
