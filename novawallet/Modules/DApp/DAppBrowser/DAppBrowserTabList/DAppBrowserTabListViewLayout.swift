import UIKit

final class DAppBrowserTabListViewLayout: UIView {
    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 24
        layout.minimumInteritemSpacing = 16

        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )

        collectionView.contentInset = .init(
            top: 0,
            left: 0,
            bottom: Constants.toolbarHeight,
            right: 0
        )

        return collectionView
    }()

    let toolbarBackgroundView: BlurBackgroundView = {
        let view = BlurBackgroundView()
        view.sideLength = 0.0
        view.borderType = []
        return view
    }()

    let toolBar: UIToolbar = {
        let view = UIToolbar()
        view.setBackgroundImage(UIImage(), forToolbarPosition: .bottom, barMetrics: .default)
        view.setShadowImage(UIImage(), forToolbarPosition: .bottom)

        return view
    }()

    let closeAllButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: "",
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorTextPrimary()
        item.applyNoLiquidGlassStyle()

        return item
    }()

    let newTabButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: R.image.iconDappNewTab(),
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorIconPrimary()
        item.applyNoLiquidGlassStyle()

        return item
    }()

    let doneButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: "",
            style: .plain,
            target: nil,
            action: nil
        )
        item.tintColor = R.color.colorTextPrimary()
        item.applyNoLiquidGlassStyle()

        return item
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
        setupStyle()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Private

private extension DAppBrowserTabListViewLayout {
    func setupLayout() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )

        addSubview(toolbarBackgroundView)
        toolbarBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-Constants.toolbarHeight)
        }

        addSubview(toolBar)
        toolBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(Constants.toolbarHeight)
        }

        toolBar.items = [
            closeAllButtonItem,
            flexibleSpace,
            newTabButtonItem,
            flexibleSpace,
            doneButtonItem
        ]
    }

    func setupStyle() {
        backgroundColor = R.color.colorSecondaryScreenBackground()
    }
}

// MARK: Constants

private extension DAppBrowserTabListViewLayout {
    enum Constants {
        static let toolbarHeight: CGFloat = 44.0
    }
}
