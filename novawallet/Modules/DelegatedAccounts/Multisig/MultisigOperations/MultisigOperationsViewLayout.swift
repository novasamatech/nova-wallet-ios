import UIKit

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

    let emptyStateView: UIView = .create { view in
        view.isHidden = true
    }

    let emptyStateImageView: UIImageView = .create { _ in
        // TODO: configure image
    }

    let emptyStateTitleLabel: UILabel = .create { view in
        view.apply(style: .footnoteSecondary)
        view.textAlignment = .center
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

        addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(32)
        }

        emptyStateView.addSubview(emptyStateImageView)
        emptyStateImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(64)
        }

        emptyStateView.addSubview(emptyStateTitleLabel)
        emptyStateTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyStateImageView.snp.bottom).offset(16)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }

        addSubview(navBarBlurView)
        navBarBlurView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top)
        }
    }
}

// MARK: - Internal

extension MultisigOperationsViewLayout {
    func showEmptyState(_ show: Bool) {
        emptyStateView.isHidden = !show
        collectionView.isHidden = show
    }
}

// MARK: - Constants

extension MultisigOperationsViewLayout {
    enum Constants {
        static let contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
        static let itemSpacing: CGFloat = 8.0
    }
}
