import UIKit

class GenericCollectionViewLayout<THeaderView: UIView>: UIView {
    var header: THeaderView = .init()

    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: compositionalLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.contentInset = settings.collectionViewContentInset
        return view
    }()

    var showHeader: (Int) -> Bool = { _ in false }

    private var settings = GenericCollectionViewLayoutSettings()
    private lazy var compositionalLayout: UICollectionViewCompositionalLayout = {
        .init { [weak self] sectionIndex, _ -> NSCollectionLayoutSection? in
            let showHeader = self?.showHeader(sectionIndex) ?? false
            return self?.createCompositionalLayout(showHeader: showHeader)
        }
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.color0x1D1D20()
        setupLayout()
    }

    init(header: THeaderView, settings: GenericCollectionViewLayoutSettings = .init()) {
        super.init(frame: .zero)

        self.header = header
        self.settings = settings

        backgroundColor = R.color.color0x1D1D20()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(header)
        addSubview(collectionView)

        header.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(settings.headerContentInsets.top)
            $0.leading.trailing.equalToSuperview().inset(settings.horizontalInset)
        }

        header.setContentHuggingPriority(.defaultLow, for: .vertical)

        collectionView.snp.makeConstraints {
            $0.top.equalTo(header.snp.bottom).offset(settings.headerContentInsets.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func createCompositionalLayout(showHeader: Bool) -> NSCollectionLayoutSection {
        .createSectionLayoutWithFullWidthRow(settings:
            .init(
                estimatedRowHeight: settings.estimatedRowHeight,
                estimatedHeaderHeight: settings.estimatedSectionHeaderHeight,
                sectionContentInsets: settings.sectionContentInsets,
                sectionInterGroupSpacing: settings.interGroupSpacing,
                header: showHeader ? .init(pinToVisibleBounds: settings.pinToVisibleBounds) : nil
            ))
    }
}

// MARK: - Settings

struct GenericCollectionViewLayoutSettings {
    var horizontalInset: CGFloat = UIConstants.horizontalInset
    var pinToVisibleBounds: Bool = true
    var estimatedHeaderHeight: CGFloat = 36
    var estimatedRowHeight: CGFloat = 56
    var estimatedSectionHeaderHeight: CGFloat = 46
    var sectionContentInsets = NSDirectionalEdgeInsets(
        top: 0,
        leading: 16,
        bottom: 0,
        trailing: 16
    )
    var interGroupSpacing: CGFloat = 0
    var collectionViewContentInset = UIEdgeInsets(
        top: 0,
        left: 0,
        bottom: 0,
        right: 0
    )
    var headerContentInsets = UIEdgeInsets(
        top: 3,
        left: 0,
        bottom: 12,
        right: 0
    )
}

// MARK: - ContentHeight

extension GenericCollectionViewLayout {
    func contentHeight(sections: Int, items: Int) -> CGFloat {
        let itemHeight = settings.estimatedRowHeight

        let sectionsHeight = settings.estimatedSectionHeaderHeight +
            settings.sectionContentInsets.top +
            settings.sectionContentInsets.bottom

        let estimatedListHeight = settings.collectionViewContentInset.top +
            CGFloat(items) * itemHeight +
            CGFloat(sections) * sectionsHeight +
            settings.collectionViewContentInset.bottom

        return settings.estimatedHeaderHeight + estimatedListHeight
    }
}
