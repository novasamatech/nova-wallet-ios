import UIKit
import UIKit_iOS

final class GovernanceYourDelegationsViewLayout: UIView {
    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(GovernanceYourDelegationCell.self)
        $0.rowHeight = UITableView.automaticDimension
    }

    var skeletonView: SkrullableView?
    var skeletonContanerView = UIView()

    let addDelegationButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(tableView)

        tableView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(addDelegationButton)

        addDelegationButton.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        tableView.contentInset = UIEdgeInsets(
            top: 8,
            left: 0,
            bottom: UIConstants.actionHeight + 2 * UIConstants.actionBottomInset,
            right: 0
        )

        insertSubview(skeletonContanerView, belowSubview: tableView)
        skeletonContanerView.snp.makeConstraints { make in
            make.top.equalTo(tableView).offset(12)
            make.leading.trailing.equalTo(tableView).inset(16)
            make.bottom.equalTo(tableView)
        }
    }
}

extension GovernanceYourDelegationsViewLayout: SkeletonableView, AdaptiveDesignable {
    var skeletonSuperview: UIView {
        skeletonContanerView
    }

    var hidingViews: [UIView] {
        [tableView]
    }

    var skeletonReplica: SkeletonableViewReplica {
        .init(count: UInt32(6 * designScaleRatio.height), spacing: 8)
    }

    var skeletonSpaceSize: CGSize {
        CGSize(width: skeletonSuperview.bounds.width, height: 206)
    }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let contentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 16, right: 12)
        let avatarSize = CGSize(width: 40, height: 40)
        let nameSize = CGSize(width: 178, height: 10)
        let typeSize = CGSize(width: 111, height: 16)
        let descriptionSize = CGSize(width: 178, height: 8)
        let statsTitleSize = CGSize(width: 47, height: 6)
        let statsDetailsSize = CGSize(width: 60, height: 10)
        let trackSize = CGSize(width: 178, height: 16)
        let yourVotesSize = CGSize(width: 50, height: 10)
        let yourConvictionSize = CGSize(width: 70, height: 10)

        let avatarOffset = CGPoint(x: contentInsets.left, y: contentInsets.top)
        let nameOffset = CGPoint(x: avatarOffset.x + avatarSize.width + 12, y: contentInsets.top + 5.0)
        let typeOffset = CGPoint(x: nameOffset.x, y: nameOffset.y + nameSize.height + 9)
        let descriptionOffset = CGPoint(x: avatarOffset.x, y: avatarOffset.y + avatarSize.height + 22)

        let delegationsTitleOffset = CGPoint(
            x: contentInsets.left,
            y: descriptionOffset.y + descriptionSize.height + 24
        )

        let delegationsDetailsOffset = CGPoint(
            x: contentInsets.left,
            y: delegationsTitleOffset.y + statsTitleSize.height + 8
        )

        let votesTitleOffset = CGPoint(x: contentInsets.left + 86, y: delegationsTitleOffset.y)
        let votesDetailsOffset = CGPoint(x: votesTitleOffset.x, y: delegationsDetailsOffset.y)

        let activityTitleOffset = CGPoint(x: contentInsets.left + 193, y: delegationsTitleOffset.y)
        let activityDetailsOffset = CGPoint(x: activityTitleOffset.x, y: delegationsDetailsOffset.y)

        let trackOffset = CGPoint(x: contentInsets.left, y: contentInsets.top + 158)
        let yourVotesOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - yourVotesSize.width,
            y: contentInsets.top + 152
        )

        let yourConvictionOffset = CGPoint(
            x: spaceSize.width - contentInsets.right - yourConvictionSize.width,
            y: yourVotesOffset.y + yourVotesSize.height + 8
        )

        let allRects: [CGRect] = [
            CGRect(origin: avatarOffset, size: avatarSize),
            CGRect(origin: nameOffset, size: nameSize),
            CGRect(origin: typeOffset, size: typeSize),
            CGRect(origin: descriptionOffset, size: descriptionSize),
            CGRect(origin: delegationsTitleOffset, size: statsTitleSize),
            CGRect(origin: delegationsDetailsOffset, size: statsDetailsSize),
            CGRect(origin: votesTitleOffset, size: statsTitleSize),
            CGRect(origin: votesDetailsOffset, size: statsDetailsSize),
            CGRect(origin: activityTitleOffset, size: statsTitleSize),
            CGRect(origin: activityDetailsOffset, size: statsDetailsSize),
            CGRect(origin: trackOffset, size: trackSize),
            CGRect(origin: yourVotesOffset, size: yourVotesSize),
            CGRect(origin: yourConvictionOffset, size: yourConvictionSize)
        ]

        return allRects.map { rect in
            SingleSkeleton.createRow(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: rect.origin,
                size: rect.size
            )
        }
    }

    func createDecorations(for spaceSize: CGSize) -> [Decorable] {
        let mainBackground = SingleDecoration.createDecoration(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: CGPoint.zero,
            size: spaceSize
        )
        .round(CGSize(width: 12 / spaceSize.width, height: 12 / spaceSize.height), mode: [.topLeft, .topRight])
        .fill(R.color.colorBlockBackground()!)

        let separatorSize = CGSize(width: 1, height: 31)

        let separatorOrigins: [CGPoint] = [
            CGPoint(x: 85, y: 102),
            CGPoint(x: 192, y: 102)
        ]

        let separators = separatorOrigins.map { origin in
            SingleDecoration.createDecoration(
                on: self,
                containerView: self,
                spaceSize: spaceSize,
                offset: origin,
                size: separatorSize
            )
            .stroke(R.color.colorDivider()!, width: 1)
        }

        let footerHeight: CGFloat = 57
        let footer = SingleDecoration.createDecoration(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: CGPoint(x: 0, y: spaceSize.height - footerHeight),
            size: CGSize(width: spaceSize.width, height: footerHeight)
        )
        .round(CGSize(width: 12 / spaceSize.width, height: 12 / spaceSize.height), mode: [.bottomLeft, .bottomRight])
        .fill(R.color.colorBlockBackground()!)

        return [mainBackground] + separators + [footer]
    }
}
