import UIKit

extension CardsZStack {
    func animateStackManage() {
        stackedViews.reversed().enumerated().forEach { index, view in
            let (scale, scaleTransform): (CGFloat, CGAffineTransform) = createScaleTransform(
                for: index
            )
            let translationTransform = createTranslationTransform(
                cardIndex: index,
                cardScale: scale,
                insertLast: false
            )
            let finalTransform = scaleTransform.concatenating(translationTransform)

            UIView.animate(
                withDuration: Constants.StackManagingAnimation.duration,
                delay: Constants.StackManagingAnimation.delay,
                usingSpringWithDamping: Constants.StackManagingAnimation.springDamping,
                initialSpringVelocity: Constants.StackManagingAnimation.springVelocity,
                options: [.curveEaseInOut]
            ) {
                view.transform = finalTransform
            }
        }
    }

    func animateCardAdd(_ cardView: UIView) {
        let (scale, scaleTransform): (CGFloat, CGAffineTransform) = createScaleTransform(
            for: stackedViews.endIndex
        )
        let translationTransform = createTranslationTransform(
            cardIndex: stackedViews.endIndex,
            cardScale: scale,
            insertLast: true
        )

        cardView.alpha = 0
        cardView.transform = scaleTransform

        UIView.animate(
            withDuration: Constants.CardAddAnimation.duration,
            delay: Constants.CardAddAnimation.delay,
            usingSpringWithDamping: Constants.CardAddAnimation.springDamping,
            initialSpringVelocity: Constants.CardAddAnimation.springVelocity,
            options: [.curveEaseInOut]
        ) {
            cardView.alpha = 1
            cardView.transform = scaleTransform.concatenating(translationTransform)
        }
    }

    func animateCardDismiss(
        _ topCard: UIView,
        direction: DismissalDirection,
        completion: @escaping () -> Void
    ) {
        let translation: (x: CGFloat, y: CGFloat) = switch direction {
        case .left: (-1.5 * bounds.width, 0)
        case .right: (1.5 * bounds.width, 0)
        case .top: (0, -1.5 * bounds.height)
        case .bottom: (0, 1.5 * bounds.height)
        }

        let rotationDirection: CGFloat = switch direction {
        case .left: -1
        case .right: 1
        case .top: 0
        case .bottom: 0
        }

        UIView.animate(
            withDuration: Constants.CardDismissAnimation.duration,
            animations: {
                topCard.transform = CGAffineTransform(rotationAngle: 0.15 * rotationDirection)
                    .translatedBy(x: translation.x, y: translation.y)
            },
            completion: { _ in
                completion()
            }
        )
    }

    func createScaleTransform(
        for cardIndex: Int
    ) -> (scale: CGFloat, transform: CGAffineTransform) {
        let scale = NSDecimalNumber(
            decimal: pow(Decimal(Constants.stackZScaling), cardIndex)
        ).doubleValue

        let transform = CGAffineTransform(
            scaleX: scale,
            y: scale
        )

        return (scale, transform)
    }

    func createTranslationTransform(
        cardIndex: Int,
        cardScale: CGFloat,
        insertLast: Bool
    ) -> CGAffineTransform {
        guard let baseHeight = stackedViews.last?.frame.height else {
            return .identity
        }

        let prevIndex = cardIndex > 0
            ? cardIndex - 1
            : cardIndex

        let heightDelta = (baseHeight - (baseHeight * cardScale)) / 2
        let translationY = heightDelta + Constants.lowerCardsOffset * CGFloat(insertLast ? prevIndex : cardIndex)

        return CGAffineTransform(
            translationX: .zero,
            y: translationY
        )
    }
}
