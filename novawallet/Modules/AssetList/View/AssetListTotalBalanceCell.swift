import UIKit
import UIKit_iOS
import Kingfisher

final class AssetListTotalBalanceCell: UICollectionViewCell {
    let totalView = AssetListTotalBalanceView()

    var locale: Locale {
        get {
            totalView.locale
        }

        set {
            totalView.locale = newValue
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AssetListHeaderViewModel) {
        totalView.bind(viewModel: viewModel)
    }

    private func setupLayout() {
        contentView.addSubview(totalView)
        totalView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }
    }
}
