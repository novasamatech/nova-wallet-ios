import UIKit
import SnapKit
import UIKit_iOS

final class AddDelegationViewLayout: UIView {
    let bannerView = GovernanceDelegateBanner()

    let filterView = GovernanceDelegateActionControl()
    let sortView = GovernanceDelegateActionControl()

    lazy var topView = UIView.vStack(spacing: 16, [
        bannerView,
        UIView.hStack(distribution: .fill, [
            filterView,
            UIView(),
            sortView
        ])
    ])

    let searchButton = UIBarButtonItem(
        image: R.image.iconSearchWhite(),
        style: .plain,
        target: nil,
        action: nil
    )

    let tableView: UITableView = .create {
        $0.separatorStyle = .none
        $0.backgroundColor = .clear
        $0.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 0, right: 0)
        $0.registerClassForCell(GovernanceDelegateTableViewCell.self)
        $0.registerClassForCell(GovernanceYourDelegationCell.self)
        $0.rowHeight = UITableView.automaticDimension
    }

    var skeletonContanerView = UIView()
    var skeletonView: SkrullableView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
        setBanner(isHidden: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setBanner(isHidden: Bool) {
        bannerView.isHidden = isHidden
        bannerView.alpha = isHidden ? 0 : 1
    }

    private func setupLayout() {
        addSubview(topView)
        topView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.trailing.equalToSuperview().inset(16)
        }
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(topView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        insertSubview(skeletonContanerView, belowSubview: tableView)
        skeletonContanerView.snp.makeConstraints {
            $0.top.equalTo(tableView).offset(12)
            $0.left.equalTo(tableView).offset(16)
            $0.right.equalTo(tableView).offset(-16)
            $0.bottom.equalTo(tableView)
        }

        [filterView, sortView].forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(32)
            }
        }

        bannerView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(148)
        }
    }
}

extension AddDelegationViewLayout: SkeletonableView, AdaptiveDesignable {
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
        CGSize(width: skeletonSuperview.bounds.width, height: 145)
    }

    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let contentInsets = UIEdgeInsets(top: 12, left: 12, bottom: 16, right: 12)
        let avatarSize = CGSize(width: 40, height: 40)
        let nameSize = CGSize(width: 178, height: 10)
        let typeSize = CGSize(width: 111, height: 16)
        let descriptionSize = CGSize(width: 178, height: 8)
        let statsTitleSize = CGSize(width: 47, height: 6)
        let statsDetailsSize = CGSize(width: 60, height: 10)

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
            CGRect(origin: activityDetailsOffset, size: statsDetailsSize)
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
        let background = SingleDecoration.createDecoration(
            on: self,
            containerView: self,
            spaceSize: spaceSize,
            offset: CGPoint.zero,
            size: spaceSize
        )
        .round(CGSize(width: 12 / spaceSize.width, height: 12 / spaceSize.height))
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

        return [background] + separators
    }
}
