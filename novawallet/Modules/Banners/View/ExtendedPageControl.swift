import Foundation
import UIKit
import UIKit_iOS

class ExtendedPageControl: UIControl {
    private var dots: [UIView] = []

    private lazy var stackView: UIStackView = .create { view in
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = Constants.spacing
    }

    private let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: Constants.animationDuration
    )
    private let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: Constants.animationDuration
    )
    private let changesAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(duration: Constants.animationDuration)

    private var previousSelectedPage: Int?

    var numberOfPages: Int = 0 {
        didSet {
            guard oldValue != numberOfPages else { return }

            if numberOfPages < oldValue {
                animateDotRemoval(oldNumberOfPage: oldValue)
            } else {
                setupDots()
            }
        }
    }

    var currentPage: Int = 0 {
        didSet {
            if oldValue != currentPage {
                previousSelectedPage = oldValue
            }

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
        dot.layer.cornerRadius = Constants.dotSize / 2
        dot.layer.masksToBounds = true
        dot.backgroundColor = R.color.colorIconInactive()

        return dot
    }

    func animateDotRemoval(oldNumberOfPage: Int) {
        guard let previousSelectedPage, previousSelectedPage != currentPage else {
            return
        }

        if previousSelectedPage < currentPage {
            animateLeadingDotRemoval(oldValue: oldNumberOfPage)
        } else {
            animateTrailingDotRemoval(oldValue: oldNumberOfPage)
        }
    }

    func animateLeadingDotRemoval(oldValue: Int) {
        guard oldValue > numberOfPages, !dots.isEmpty else { return }

        let dotToRemove = dots.removeFirst()

        changesAnimator.animate { [weak self] in
            guard let self else { return }

            dotToRemove.snp.updateConstraints { make in
                make.width.equalTo(0)
            }

            stackView.setCustomSpacing(0, after: dotToRemove)

            self.layoutIfNeeded()
        } completionBlock: { _ in
            dotToRemove.removeFromSuperview()
        }
    }

    func animateTrailingDotRemoval(oldValue: Int) {
        guard oldValue > numberOfPages, dots.count > 1 else { return }

        let dotToRemove = dots.removeLast()
        let newLastDot = dots.last!

        disappearanceAnimator.animate(view: dotToRemove) { [weak self] _ in
            self?.stackView.setCustomSpacing(0, after: newLastDot)
            dotToRemove.removeFromSuperview()
        }
    }

    func updateDots(animated: Bool) {
        guard currentPage < dots.count else { return }

        if animated {
            changesAnimator.animate(
                block: updateDots,
                completionBlock: nil
            )
        } else {
            updateDots()
        }
    }

    func updateDots() {
        dots.enumerated().forEach { index, dot in
            if index == self.currentPage {
                dot.snp.updateConstraints { make in
                    make.width.equalTo(Constants.extendedDotWidth)
                }
            } else {
                dot.snp.updateConstraints { make in
                    make.width.equalTo(Constants.dotSize)
                }
            }
        }
        layoutIfNeeded()
    }
}

// MARK: Internal

extension ExtendedPageControl {
    func show() {
        guard stackView.isHidden else { return }

        stackView.isHidden = false

        appearanceAnimator.animate(
            view: stackView,
            completionBlock: nil
        )
    }

    func hide() {
        guard !stackView.isHidden else { return }

        disappearanceAnimator.animate(view: stackView) { [weak self] _ in
            self?.stackView.isHidden = true
        }
    }
}

// MARK: Constants

extension ExtendedPageControl {
    enum Constants {
        static let animationDuration: CGFloat = 0.3
        static let dotSize: CGFloat = 6.0
        static let extendedDotWidth: CGFloat = 20
        static let spacing: CGFloat = 6
    }
}
