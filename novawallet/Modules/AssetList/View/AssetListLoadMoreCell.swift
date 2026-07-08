import UIKit

final class AssetListLoadMoreCell: UICollectionViewCell {
    let actionButton: UIButton = .create {
        $0.setTitleColor(R.color.colorIconAccent(), for: .normal)
        $0.titleLabel?.font = .semiBoldSubheadline
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(title: String) {
        actionButton.setTitle(title, for: .normal)
    }

    private func setupLayout() {
        contentView.addSubview(actionButton)

        actionButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }
}
