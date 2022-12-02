import UIKit

final class TopCustomSearchView: UIView {
    static let preferredNavigationBarHeight: CGFloat = 48.0

    let blurBackgroundView: BlurBackgroundView = {
        let view = BlurBackgroundView()
        view.sideLength = 0.0
        return view
    }()

    let searchBar = CustomSearchBar()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(blurBackgroundView)

        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.trailing.equalToSuperview().inset(16.0)
            make.bottom.equalToSuperview().inset(6)
            make.height.equalTo(36.0)
        }
    }
}
