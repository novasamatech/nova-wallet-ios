import UIKit
import UIKit_iOS

extension StartStakingInfoViewLayout: SkeletonableView {
    var skeletonSuperview: UIView {
        containerView
    }

    var hidingViews: [UIView] {
        [
            header,
            wikiView,
            termsView
        ] + paragraphViews
    }

    // swiftlint:disable:next function_body_length
    func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let offsetX: CGFloat = 18
        let offsetY: CGFloat = 39
        let spacing: CGFloat = 55
        let iconSize = CGSize(width: 28, height: 28)
        let titleSize = CGSize(width: 155, height: 10)
        let subtitleSize = CGSize(width: 126, height: 10)

        let headerFirstLineSize = CGSize(width: 145, height: 16)
        let headerSecondLineSize = CGSize(width: 185, height: 16)
        let headerThirdLineSize = CGSize(width: 109, height: 16)

        let topOffsetY = safeAreaInsets.top + 23

        let headerFirstLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerFirstLineSize.width / 2,
            y: topOffsetY
        )

        let headerFirstLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerFirstLineOffset,
            size: headerFirstLineSize
        )
        let headerSecondLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerSecondLineSize.width / 2,
            y: headerFirstLineOffset.y + headerFirstLineSize.height + 17
        )
        let headerSecondLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerSecondLineOffset,
            size: headerSecondLineSize
        )

        let headerThirdLineOffset = CGPoint(
            x: spaceSize.width / 2 - headerThirdLineSize.width / 2,
            y: headerSecondLineOffset.y + headerSecondLineSize.height + 17
        )
        let headerThirdLineSkeleton = SingleSkeleton.createRow(
            on: containerView,
            containerView: containerView,
            spaceSize: spaceSize,
            offset: headerThirdLineOffset,
            size: headerThirdLineSize
        )

        let compoundSkeletons: [[Skeletonable]] = (0 ..< 5).map { index in
            let iconOffset = CGPoint(
                x: offsetX,
                y: headerThirdLineOffset.y + offsetY + CGFloat(index) * (iconSize.height + spacing)
            )

            let iconSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: iconOffset,
                size: iconSize
            )

            let titleOffset = CGPoint(
                x: iconOffset.x + iconSize.width + 18,
                y: iconOffset.y + 7
            )

            let titleSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: titleOffset,
                size: titleSize
            )

            let subtitleOffset = CGPoint(
                x: titleOffset.x,
                y: titleOffset.y + titleSize.height + 15
            )

            let subtitleSkeleton = SingleSkeleton.createRow(
                on: containerView,
                containerView: containerView,
                spaceSize: spaceSize,
                offset: subtitleOffset,
                size: subtitleSize
            )

            return [iconSkeleton, titleSkeleton, subtitleSkeleton]
        }

        return [
            headerFirstLineSkeleton,
            headerSecondLineSkeleton,
            headerThirdLineSkeleton
        ] + compoundSkeletons.flatMap { $0 }
    }
}
