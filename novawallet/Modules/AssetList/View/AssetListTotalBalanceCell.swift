import UIKit
import UIKit_iOS
import Kingfisher

final class AssetListTotalBalanceCell: UICollectionViewCell {
    let cellBackgroundView: RoundedView = .create { view in
        view.applyCellBackgroundStyle()
        view.cornerRadius = 12
    }

    let totalView = AssetListTotalBalanceView()

    let cardView = AssetListCardView()

    var locale: Locale {
        get {
            totalView.locale
        }

        set {
            totalView.locale = newValue
            cardView.locale = newValue
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
        contentView.addSubview(cellBackgroundView)

        let cellContentView = UIView.vStack(spacing: 0, [totalView, cardView])

        contentView.addSubview(cellContentView)
        cellContentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.bottom.equalToSuperview()
        }

        cellBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(totalView.snp.centerY)
            make.bottom.equalToSuperview()
        }
    }
}
