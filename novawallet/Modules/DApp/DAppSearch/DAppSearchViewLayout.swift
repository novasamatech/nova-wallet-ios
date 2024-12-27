import UIKit
import SoraUI

final class DAppSearchViewLayout: UIView {
    let searchBar = CustomSearchBar()

    let categoriesView: DAppCategoriesView = .create { view in
        view.alpha = 0.0
    }

    let topContainerView = UIView()

    let topBackgroundView: BlurBackgroundView = .create { view in
        view.sideLength = 0.0
        view.borderType = []
    }

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.separatorStyle = .none
        return view
    }()

    let cancelBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem()
        item.tintColor = R.color.colorIconAccent()
        return item
    }()

    private let appearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 0.0,
        to: 1.0,
        duration: 0.15
    )
    private let disappearanceAnimator: ViewAnimatorProtocol = FadeAnimator(
        from: 1.0,
        to: 0.0,
        duration: 0.15
    )
    private let blockAnimator: BlockViewAnimatorProtocol = BlockViewAnimator(
        duration: 0.2,
        delay: 0.0,
        options: [.curveLinear]
    )

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(topBackgroundView)
        addSubview(categoriesView)
        addSubview(tableView)

        categoriesView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(0.0)
            make.leading.trailing.equalToSuperview()
        }

        topBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(categoriesView)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(categoriesView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func updateCategoriesView(with viewModels: [DAppCategoryViewModel]) {
        guard viewModels.isEmpty != categoriesView.viewModels.isEmpty else {
            categoriesView.bind(categories: viewModels)

            return
        }

        if viewModels.isEmpty {
            hideCategoriesView { [weak self] in
                self?.categoriesView.bind(categories: viewModels)
            }
        } else {
            categoriesView.bind(categories: viewModels)
            showCategoriesView()
        }
    }

    func hideCategoriesView(updateClosure: @escaping () -> Void) {
        categoriesView.snp.updateConstraints { make in
            make.height.equalTo(0.0)
        }

        disappearanceAnimator.animate(
            view: categoriesView,
            completionBlock: nil
        )

        blockAnimator.animate(
            block: { [weak self] in self?.layoutIfNeeded() },
            completionBlock: { _ in updateClosure() }
        )
    }

    func showCategoriesView() {
        categoriesView.snp.updateConstraints { make in
            make.height.equalTo(DAppCategoriesView.preferredHeight)
        }

        blockAnimator.animate(
            block: { [weak self] in self?.layoutIfNeeded() },
            completionBlock: { [weak self] _ in
                guard let self else { return }

                appearanceAnimator.animate(
                    view: categoriesView,
                    completionBlock: nil
                )
            }
        )
    }
}
