import UIKit
import SnapKit

final class NftListViewLayout: UIView {
    static let contentInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 16.0, right: 16.0)
    static let horizontalSpacing: CGFloat = 11.0
    static let verticalSpacing: CGFloat = 18.0

    let backgroundView = MultigradientView.background

    let navBarBlurView: UIView = {
        let blurView = TriangularedBlurView()
        blurView.cornerCut = []
        return blurView
    }()

    var navBarBlurViewHeightConstraint: Constraint!

    let collectionView: UICollectionView = {
        let flowLayout = UICollectionViewFlowLayout()
        let view = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .always
        view.refreshControl = UIRefreshControl()

        return view
    }()

    let counterView: BorderedLabelView = {
        let view = BorderedLabelView()
        view.titleLabel.textColor = R.color.colorWhite()!
        view.titleLabel.font = .regularFootnote
        view.contentInsets = UIEdgeInsets(top: 2.0, left: 8.0, bottom: 2.0, right: 8.0)
        view.backgroundView.cornerRadius = 6.0
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        collectionView.contentInset = Self.contentInsets

        let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        flowLayout?.minimumInteritemSpacing = Self.horizontalSpacing
        flowLayout?.minimumLineSpacing = Self.verticalSpacing

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
            self.navBarBlurViewHeightConstraint = make.height.equalTo(0).constraint
            self.navBarBlurViewHeightConstraint.activate()
        }
    }
}
