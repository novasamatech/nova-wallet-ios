import UIKit
import UIKit_iOS

protocol DAppCategoriesViewDelegate: AnyObject {
    func dAppCategories(
        view: DAppCategoriesView,
        didSelectCategoryWith identifier: String?
    )
}

private typealias CategoryChip = GenericBorderedView<IconDetailsView>

class DAppCategoriesViewCell: CollectionViewContainerCell<DAppCategoriesView> {
    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        layoutAttributes.frame.size = CGSize(
            width: layoutAttributes.frame.width,
            height: DAppCategoriesView.preferredHeight
        )

        return layoutAttributes
    }
}

final class DAppCategoriesView: UIView {
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

    var chagesStateOnSelect: Bool = true

    private var categoryItems: [CategoryChip] = []
    var viewModels: [DAppCategoryViewModel] = []

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

    func bind(categories: [DAppCategoryViewModel]) {
        guard viewModels != categories else { return }

        viewModels = categories

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
                let chip = createChip(with: categoryItems.endIndex)
                setNormalStyle(for: chip)

                containerView.stackView.addArrangedSubview(chip)
                chip.snp.makeConstraints { make in
                    make.height.equalTo(Constants.buttonHeight)
                }

                categoryItems.append(chip)
            }
        }

        for (index, category) in categories.enumerated() {
            category.imageViewModel?.cancel(on: categoryItems[index].contentView.imageView)
            category.imageViewModel?.loadImage(
                on: categoryItems[index].contentView.imageView,
                targetSize: CGSize(width: 20, height: 20),
                animated: true
            )
            categoryItems[index].contentView.detailsLabel.text = category.title
        }

        if let currentIndex = selectedIndex, currentIndex >= categories.count {
            selectedIndex = nil
        }

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
    }

    private func createChip(with index: Int) -> CategoryChip {
        .create { view in
            view.backgroundView.apply(style: .roundedChips(radius: 10.0))
            view.contentView.detailsLabel.apply(style: .semiboldFootnotePrimary)
            view.contentView.spacing = 9.25

            view.tag = index
            view.addGestureRecognizer(
                UITapGestureRecognizer(
                    target: self,
                    action: #selector(actionButton(sender:))
                )
            )
        }
    }

    private func setSelectedStyle(for categoryChip: CategoryChip) {
        let templateIcon = categoryChip.contentView.imageView.image?.withRenderingMode(.alwaysTemplate)

        categoryChip.contentView.detailsLabel.textColor = R.color.colorTextPrimaryNegative()!
        categoryChip.contentView.imageView.image = templateIcon
        categoryChip.contentView.imageView.tintColor = R.color.colorIconPrimaryNegative()!

        categoryChip.backgroundView.fillColor = R.color.colorSelectedDAppCategoryBackground()!
    }

    private func setNormalStyle(for categoryChip: CategoryChip) {
        let originalIcon = categoryChip.contentView.imageView.image?.withRenderingMode(.alwaysOriginal)

        categoryChip.contentView.detailsLabel.textColor = R.color.colorTextPrimary()!
        categoryChip.contentView.imageView.image = originalIcon
        categoryChip.backgroundView.fillColor = R.color.colorButtonBackgroundSecondary()!
    }

    @objc private func actionButton(sender: UITapGestureRecognizer) {
        var index = sender.view?.tag
        var selectedCategory: DAppCategoryViewModel?

        if selectedIndex != index, let index {
            selectedCategory = viewModels[index]
        } else {
            index = nil
        }

        if chagesStateOnSelect {
            setSelectedIndex(index, animated: true)
        }

        delegate?.dAppCategories(
            view: self,
            didSelectCategoryWith: selectedCategory?.identifier
        )
    }
}

// MARK: Private Constants

private extension DAppCategoriesView {
    enum Constants {
        static let layoutMargins = UIEdgeInsets(
            top: .zero,
            left: 16.0,
            bottom: .zero,
            right: 16.0
        )
        static let buttonHeight: CGFloat = 32
    }
}

// MARK: Internal Constants

extension DAppCategoriesView {
    static var preferredHeight: CGFloat {
        Constants.buttonHeight
    }
}
