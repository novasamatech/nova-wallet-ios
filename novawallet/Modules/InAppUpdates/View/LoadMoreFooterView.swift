import SoraUI
import UIKit

final class LoadMoreFooterView: UITableViewHeaderFooterView {
    let moreButton: RoundedButton = .create { button in
        button.applyIconStyle()
        let color = R.color.colorButtonTextAccent()!
        button.imageWithTitleView?.titleColor = color
        button.imageWithTitleView?.titleFont = .regularFootnote
    }

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupLayout() {
        contentView.addSubview(moreButton)
        moreButton.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(8)
            $0.centerX.equalToSuperview()
        }
    }

    func bind(text: String) {
        moreButton.imageWithTitleView?.title = text
    }
}
