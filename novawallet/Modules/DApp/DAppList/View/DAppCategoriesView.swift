import UIKit
import SoraUI

protocol DAppCategoriesViewDelegate: AnyObject {
    func dAppCategories(view: DAppCategoriesView, didSelectItemAt index: Int)
}

final class DAppCategoriesView: UICollectionViewCell {
    private enum Constants {
        static let layoutMargins = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
        static let buttonHeight: CGFloat = 36
    }

    static var preferredHeight: CGFloat {
        Constants.layoutMargins.top + Constants.layoutMargins.bottom + Constants.buttonHeight
    }

    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .horizontal)
        view.stackView.distribution = .fill
        view.stackView.alignment = .center
        view.stackView.layoutMargins = Constants.layoutMargins
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.spacing = 8.0
        view.scrollView.showsHorizontalScrollIndicator = false
        return view
    }()

    weak var delegate: DAppCategoriesViewDelegate?

    private var categoryItems: [RoundedButton] = []

    private(set) var selectedIndex: Int?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(width: layoutAttributes.frame.width, height: Self.preferredHeight)
        return layoutAttributes
    }

    func setSelectedIndex(_ newIndex: Int?, animated: Bool) {
        guard selectedIndex != newIndex else {
            return
        }

        if let oldIndex = selectedIndex {
            setNormalStyle(for: categoryItems[oldIndex])
        }

        if let newIndex = newIndex {
            setSelectedStyle(for: categoryItems[newIndex])

            let button = categoryItems[newIndex]
            let buttonFrame = containerView.scrollView.convert(button.frame, from: button.superview)
            containerView.scrollView.scrollRectToVisible(buttonFrame, animated: animated)
        }

        selectedIndex = newIndex
    }

    func bind(categories: [String]) {
        if categoryItems.count > categories.count {
            let itemsToRemove = categoryItems.count - categories.count

            (0 ..< itemsToRemove).forEach { _ in
                if let button = categoryItems.popLast() {
                    button.removeFromSuperview()
                }
            }
        } else if categoryItems.count < categories.count {
            let itemsToInsert = categories.count - categoryItems.count

            (0 ..< itemsToInsert).forEach { _ in
                let button = createButton()
                setNormalStyle(for: button)

                containerView.stackView.addArrangedSubview(button)
                button.snp.makeConstraints { make in
                    make.height.equalTo(Constants.buttonHeight)
                }

                categoryItems.append(button)
            }
        }

        for (index, category) in categories.enumerated() {
            categoryItems[index].imageWithTitleView?.title = category
            categoryItems[index].invalidateLayout()
        }

        if let currentIndex = selectedIndex, currentIndex >= categories.count {
            selectedIndex = nil
        }

        setNeedsLayout()
    }

    private func setupLayout() {
        contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }

    private func createButton() -> RoundedButton {
        let button = RoundedButton()
        button.imageWithTitleView?.titleFont = .regularFootnote
        button.roundedBackgroundView?.shadowOpacity = 0.0
        button.roundedBackgroundView?.strokeWidth = 0.0
        button.changesContentOpacityWhenHighlighted = true
        button.contentInsets = UIEdgeInsets(top: 9.0, left: 9.0, bottom: 9.0, right: 9.0)
        button.addTarget(self, action: #selector(actionButton(sender:)), for: .touchUpInside)
        return button
    }

    private func setSelectedStyle(for button: RoundedButton) {
        button.imageWithTitleView?.titleColor = R.color.colorWhite()!
        button.roundedBackgroundView?.fillColor = R.color.colorWhite16()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorWhite16()!
    }

    private func setNormalStyle(for button: RoundedButton) {
        button.imageWithTitleView?.titleColor = R.color.colorTransparentText()!
        button.roundedBackgroundView?.fillColor = .clear
        button.roundedBackgroundView?.highlightedFillColor = .clear
    }

    @objc private func actionButton(sender: RoundedButton) {
        guard let index = categoryItems.firstIndex(of: sender) else {
            return
        }

        setSelectedIndex(index, animated: true)

        delegate?.dAppCategories(view: self, didSelectItemAt: index)
    }
}
