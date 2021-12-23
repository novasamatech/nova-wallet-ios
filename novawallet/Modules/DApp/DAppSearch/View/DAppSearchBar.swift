import UIKit
import SoraUI

final class DAppSearchBar: UIView {
    let textFieldBackgroundView: RoundedView = {
        let view = RoundedView()
        view.applyFilledBackgroundStyle()
        view.fillColor = R.color.colorWhite8()!
        view.highlightedFillColor = R.color.colorWhite8()!

        return view
    }()

    let textField: UITextField = {
        let view = UITextField()
        view.textColor = R.color.colorWhite()
        view.font = .regularFootnote
        view.background = UIImage()
        view.tintColor = R.color.colorWhite()
        view.returnKeyType = .go
        view.clearButtonMode = .whileEditing
        view.autocapitalizationType = .none

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
