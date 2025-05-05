import UIKit
import UIKit_iOS

final class CustomSearchBar: UIView {
    let textFieldBackgroundView: RoundedView = {
        let view = RoundedView()
        view.apply(style: .searchBarTextField)
        return view
    }()

    let textField: UITextField = {
        let view = UITextField()
        view.textColor = R.color.colorTextPrimary()
        view.font = .regularFootnote
        view.background = UIImage()
        view.tintColor = R.color.colorTextPrimary()
        view.returnKeyType = .go
        view.clearButtonMode = .whileEditing
        view.autocapitalizationType = .none
        let searchButton = RoundedButton()
        searchButton.applyIconStyle()
        searchButton.contentInsets = .init(top: 0, left: 0, bottom: 0, right: 6)
        searchButton.imageWithTitleView?.iconImage = R.image.iconSearch()
        view.leftViewMode = .always
        view.leftView = searchButton
        return view
    }()

    override var intrinsicContentSize: CGSize {
        let width = UIView.layoutFittingExpandedSize.width

        return CGSize(width: width, height: 36.0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()

        return textField.becomeFirstResponder()
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()

        return textField.resignFirstResponder()
    }

    private func setupLayout() {
        addSubview(textFieldBackgroundView)
        textFieldBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        textFieldBackgroundView.addSubview(textField)
        textField.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(12.0)
            make.top.bottom.equalToSuperview()
        }
    }
}
