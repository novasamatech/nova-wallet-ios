import UIKit
import UIKit_iOS

final class VotesViewLayout: UIView, AdaptiveDesignable {
    var skeletonView: SkrullableView?

    let totalVotersLabel: BorderedLabelView = .create { view in
        view.backgroundView.fillColor = R.color.colorChipsBackground()!
        view.titleLabel.apply(style: .init(textColor: R.color.colorChipText()!, font: .semiBoldFootnote))
        view.contentInsets = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        view.backgroundView.cornerRadius = 6
    }

    let refreshControl = UIRefreshControl()

    let tableView: UITableView = .create { view in
        view.separatorStyle = .none
        view.backgroundColor = .clear
        view.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    func updateRefreshControlState(isAvailable: Bool) {
        let refreshControl = isAvailable ? refreshControl : nil
        tableView.refreshControl = refreshControl
    }
}

extension VotesViewLayout: SkeletonableView {
    var skeletonSpaceSize: CGSize {
        CGSize(width: frame.width, height: VotesTableViewCell.Constants.rowHeight)
    }

    var skeletonReplica: SkeletonableViewReplica {
        let count = UInt32(20 * designScaleRatio.height)

        return SkeletonableViewReplica(count: count, spacing: 0.0)
    }

    var hidingViews: [UIView] { [] }

    var skeletonSuperview: UIView { self }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let centerY = tableView.contentInset.top + spaceSize.height / 2.0
        let insetX = UIConstants.horizontalInset

        let imageSize = CGSize(width: 22.0, height: 22.0)

        let nameSize = CGSize(width: 120.0, height: 14)
        let nameOffsetX = insetX + imageSize.width + VotesTableViewCell.Constants.addressNameSpacing

        let indicatorSize = CGSize(width: 12, height: 12)
        let indicatorOffsetX = nameOffsetX + nameSize.width +
            VotesTableViewCell.Constants.addressIndicatorSpacing

        let votesSize = CGSize(width: 60, height: 14)

        let votesDetailsSize = CGSize(width: 80, height: 14)

        return [
            SingleSkeleton.createRow(
                on: tableView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: insetX, y: centerY - imageSize.height / 2.0),
                size: imageSize
            ),
            SingleSkeleton.createRow(
                on: tableView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: nameOffsetX, y: centerY - nameSize.height / 2.0),
                size: nameSize
            ),
            SingleSkeleton.createRow(
                on: tableView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(x: indicatorOffsetX, y: centerY - indicatorSize.height / 2.0),
                size: indicatorSize
            ),
            SingleSkeleton.createRow(
                on: tableView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: spaceSize.width - UIConstants.horizontalInset - votesSize.width,
                    y: tableView.contentInset.top + spaceSize.height / 3 - votesSize.height / 2.0
                ),
                size: votesSize
            ),
            SingleSkeleton.createRow(
                on: tableView,
                containerView: self,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: spaceSize.width - UIConstants.horizontalInset - votesDetailsSize.width,
                    y: tableView.contentInset.top + 2 * spaceSize.height / 3 - votesDetailsSize.height / 2.0
                ),
                size: votesDetailsSize
            )
        ]
    }
}
