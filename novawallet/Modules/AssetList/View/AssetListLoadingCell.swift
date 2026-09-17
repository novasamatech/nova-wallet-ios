import UIKit
import UIKit_iOS

final class AssetListLoadingCell: UICollectionViewCell {
    let loadingView: LoadingView = {
        let view = NovaLoadingViewFactory.createLoadingView()
        view.backgroundColor = .clear

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

    override func prepareForReuse() {
        super.prepareForReuse()

        loadingView.stopAnimating()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            loadingView.stopAnimating()
        } else {
            loadingView.startAnimating()
        }
    }

    func startAnimating() {
        loadingView.startAnimating()
    }
}

private extension AssetListLoadingCell {
    func setupLayout() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
