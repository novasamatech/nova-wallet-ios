import UIKit
import UIKit_iOS

final class MultisigOperationsViewLayout: UIView {
    let backgroundView = MultigradientView.background

    let navBarBlurView: BlurBackgroundView = .create {
        $0.cornerCut = []
    }

    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset.top = Constants.itemSpacing
        layout.sectionInset.bottom = Constants.itemSpacing
        layout.minimumLineSpacing = Constants.itemSpacing
        layout.minimumInteritemSpacing = 0

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.showsVerticalScrollIndicator = false

        return view
    }()

    var emptyStateView: EmptyStateView?

    var locale: Locale? {
        didSet {
            setupLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Private

private extension MultisigOperationsViewLayout {
    func setupLayout() {
        collectionView.contentInset = Constants.contentInsets

        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
    }

    func createEmptyStateView() -> EmptyStateView {
        let view = EmptyStateView()

        view.image = R.image.iconHistoryEmptyDark()
        view.verticalSpacing = 0
        view.titleColor = R.color.colorTextSecondary()!
        view.titleFont = .regularFootnote

        return view
    }

    func setupLocalization() {
        emptyStateView?.title = R.string(
            preferredLanguages: locale.rLanguages
        ).localizable.multisigOperationsEmptyText()
    }
}

// MARK: - Internal

extension MultisigOperationsViewLayout {
    func showContent() {
        emptyStateView?.removeFromSuperview()
        emptyStateView = nil
        collectionView.isHidden = false
    }

    func showEmptyState() {
        collectionView.isHidden = true

        guard emptyStateView == nil else {
            return
        }

        let emptyStateView = createEmptyStateView()

        addSubview(emptyStateView)

        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.emptyStateView = emptyStateView

        setupLocalization()
    }
}

// MARK: - Constants

extension MultisigOperationsViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 16.0, left: .zero, bottom: 16.0, right: .zero)
        static let itemSpacing: CGFloat = 8.0
    }
}
