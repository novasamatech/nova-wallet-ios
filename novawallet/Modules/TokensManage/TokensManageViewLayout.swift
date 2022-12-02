import UIKit

final class TokensManageViewLayout: UIView {
    let searchView = TopCustomSearchView()

    var searchBar: CustomSearchBar {
        searchView.searchBar
    }

    var searchTextField: UITextField {
        searchBar.textField
    }

    let addTokenButton: UIBarButtonItem = {
        let button = UIBarButtonItem()
        button.style = .plain

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: R.color.colorButtonTextAccent()!,
            .font: UIFont.regularSubheadline
        ]

        button.setTitleTextAttributes(attributes, for: .normal)
        button.setTitleTextAttributes(attributes, for: .highlighted)

        return button
    }()

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
        addSubview(searchView)

        searchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.top).offset(TopCustomSearchView.preferredNavigationBarHeight)
        }
    }
}
