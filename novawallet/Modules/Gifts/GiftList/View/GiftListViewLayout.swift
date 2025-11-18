import UIKit

final class GiftListViewLayout: UIView {
    lazy var collectionView: UICollectionView = {
        let layout = createCompositionalLayout()
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = UIEdgeInsets(
            top: Constants.collectionViewVerticalInset,
            left: 0.0,
            bottom: Constants.collectionViewVerticalInset,
            right: 0.0
        )
        view.refreshControl = UIRefreshControl()
        return view
    }()

    let actionButton: TriangularedButton = .create { view in
        view.applyDefaultStyle()
    }

    lazy var onboardingView = GiftsOnboardingView()

    let loadingView = ListLoadingView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupInitialLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension GiftListViewLayout {
    func createCompositionalLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { sectionIndex, _ in
            if sectionIndex == 0 {
                return self.createHeaderSection()
            } else {
                return self.createGiftsSection()
            }
        }
    }

    func createHeaderSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(Constants.estimatedHeaderHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(Constants.estimatedHeaderHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)

        section.contentInsets = .init(
            top: .zero,
            leading: 16.0,
            bottom: 16,
            trailing: 16.0
        )

        return section
    }

    func createGiftsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(Constants.giftItemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(Constants.giftItemHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Constants.interItemSpacing

        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(32)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading,
            absoluteOffset: .init(x: .zero, y: -Constants.interItemSpacing)
        )
        section.boundarySupplementaryItems = [header]

        return section
    }

    func setupInitialLayout() {
        layoutTableView()
        layoutButton()
        layoutLoadingView()
    }

    // MARK: - Table View

    func layoutTableView() {
        addSubview(collectionView)

        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    // MARK: - Button

    func layoutButton() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    // MARK: - Loading

    func layoutLoadingView() {
        guard loadingView.superview == nil else { return }

        addSubview(loadingView)
        loadingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func applyLoading() {
        layoutLoadingView()
        loadingView.start()
    }

    func stopLoading() {
        loadingView.stop()
        loadingView.removeFromSuperview()
    }

    // MARK: - Onboarding

    func layoutOnboarding() {
        guard onboardingView.superview == nil else { return }

        addSubview(onboardingView)
        onboardingView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func applyOnboarding(viewModel: GiftsOnboardingViewModel) {
        layoutOnboarding()
        onboardingView.bind(viewModel: viewModel)
    }

    func removeOnboarding() {
        onboardingView.removeFromSuperview()
    }
}

// MARK: - Internal

extension GiftListViewLayout {
    func bind(loading: Bool) {
        if loading { applyLoading() }
        else { stopLoading() }
    }

    func bind(contentModel: ContentModel) {
        switch contentModel {
        case let .onboarding(viewModel):
            applyOnboarding(viewModel: viewModel)
        case .list:
            removeOnboarding()
        }
    }
}

// MARK: - Constants

extension GiftListViewLayout {
    enum Constants {
        static let giftItemHeight: CGFloat = 64.0
        static let estimatedHeaderHeight: CGFloat = 100.0
        static let interItemSpacing: CGFloat = 8.0
        static let collectionViewVerticalInset: CGFloat = 16.0
    }
}

extension GiftListViewLayout {
    enum ContentModel {
        case onboarding(GiftsOnboardingViewModel)
        case list
    }
}
