import UIKit

typealias AssetListEmptyCell = CollectionViewContainerCell<AssetListEmptyView>

extension AssetListEmptyCell {
    var actionButton: UIButton {
        view.actionButton
    }

    func bind(text: String, actionTitle: String) {
        view.bind(text: text)
        actionButton.setTitle(actionTitle, for: .normal)
    }
}

final class AssetListEmptyView: EmptyCellContentView {
    let actionButton: UIButton = .create {
        $0.setTitleColor(R.color.colorIconAccent(), for: .normal)
    }

    override func setupLayout() {
        super.setupLayout()

        addSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.top.equalTo(detailsLabel.snp.bottom)
            make.centerX.equalToSuperview()
            make.height.equalTo(32)
        }
    }
}
