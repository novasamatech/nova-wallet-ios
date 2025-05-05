import Foundation
import UIKit
import UIKit_iOS

final class CustomSearchView: UIView {
    let blurBackgroundView: BlurBackgroundView = {
        let view = BlurBackgroundView()
        view.sideLength = 0.0
        return view
    }()

    let searchBar = CustomSearchBar()

    let cancelButton: RoundedButton = {
        let item = RoundedButton()
        item.applyIconStyle()
        item.imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()
        item.imageWithTitleView?.titleFont = .regularSubheadline
        item.contentInsets = UIEdgeInsets(top: 0.0, left: 16.0, bottom: 0.0, right: 16.0)
        return item
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        return searchBar.becomeFirstResponder()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()

        return searchBar.resignFirstResponder()
    }

    private func setupLayout() {
        addSubview(blurBackgroundView)

        blurBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(6)
            make.height.equalTo(36.0)
        }

        addSubview(searchBar)
        searchBar.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16.0)
            make.trailing.equalTo(cancelButton.snp.leading)
            make.bottom.equalToSuperview().inset(6)
            make.height.equalTo(36.0)
        }

        cancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
