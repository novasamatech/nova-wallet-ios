import UIKit
import UIKit_iOS

final class StakingDashboardAnnouncementCell: UICollectionViewCell {
    let alertView = InlineAlertView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: AnnouncementViewModel) {
        alertView.bind(announcement: viewModel)
    }

    private func setupLayout() {
        contentView.addSubview(alertView)

        alertView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }
    }
}

extension StakingDashboardAnnouncementCell {
    static func estimateHeight(
        for viewModel: AnnouncementViewModel,
        collectionWidth: CGFloat
    ) -> CGFloat {
        InlineAlertView.estimatedHeight(
            for: viewModel.message,
            width: collectionWidth - 2 * UIConstants.horizontalInset
        )
    }
}
