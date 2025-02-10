import UIKit
import SoraUI

final class BannersViewLayout: UIView {
    let containerView: UIView = .create { view in
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
    }

    let backgroundView = BannerBackgroundView()

    let closeButton: RoundedButton = .create { button in
        button.applyIconStyle()
        button.imageWithTitleView?.iconImage = R.image.iconCloseWithBg()!
    }

    lazy var pageControl = ExtendedPageControl()

    lazy var collectionView: UICollectionView = {
        let layout = BannersCollectionViewLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.bounces = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isPagingEnabled = true

        return collectionView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        collectionView.backgroundColor = .clear
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension BannersViewLayout {
    func setupLayout() {
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        containerView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.bottom.equalToSuperview().inset(8)
        }

        containerView.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalTo(backgroundView)
        }

        containerView.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.bottom.leading.equalTo(backgroundView).inset(16)
        }

        containerView.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.size.equalTo(24)
            make.top.equalTo(backgroundView).inset(10)
            make.trailing.equalTo(backgroundView).inset(16)
        }
    }
}

// MARK: Internal

extension BannersViewLayout {
    func setBackgroundImage(_ image: UIImage?) {
        backgroundView.setBackground(image)
    }

    func setCloseButton(available: Bool) {
        closeButton.isHidden = !available
    }

    func setLoading() {}

    func setDisplayContent() {}
}
