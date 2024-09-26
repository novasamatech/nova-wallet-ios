import Foundation
import UIKit

extension CardsZStack {
    enum Constants {
        enum CardIdentityAnimation {
            static let duration: CGFloat = 0.35
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.75
            static let springVelocity: CGFloat = 0.6
        }

        enum CardDismissAnimation {
            static let duration: CGFloat = 0.35
        }

        enum CardAddAnimation {
            static let duration: CGFloat = 0.35
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.75
            static let springVelocity: CGFloat = 0.6
        }

        enum StackManagingAnimation {
            static let duration: CGFloat = 0.3
            static let delay: CGFloat = .zero
            static let springDamping: CGFloat = 0.6
            static let springVelocity: CGFloat = 0.3
        }

        enum EmptyStateAnimation {
            static let startDuration: CGFloat = 0.2
            static let endDuration: CGFloat = 0.1
        }

        static let emptyStateHideScaling: CGFloat = 0.8
        static let emptyStateShowScaling: CGFloat = 1.05
        static let cardCornerRadius: CGFloat = 16
        static let stackZScaling: CGFloat = 0.9
        static let lowerCardsOffset: CGFloat = 10.0
        static let horizontalScreenSizeDivider: CGFloat = 6.14
        static let verticalScreenSizeDivider: CGFloat = 8.14
        static let topMostY = -(UIScreen.main.bounds.height / Constants.verticalScreenSizeDivider)
        static let leftMostX = -(UIScreen.main.bounds.width / Constants.horizontalScreenSizeDivider)
        static let rightMostX = UIScreen.main.bounds.width / Constants.horizontalScreenSizeDivider
    }
}
