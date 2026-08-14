import Foundation
import UIKit_iOS
import UIKit

extension ModalSheetPresentationStyle {
    static var novaManual: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 32.0, height: 3.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.colorBottomSheetBackground()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: indicatorSize,
            indicatorColor: R.color.colorPullIndicator()!
        )
        let style = ModalSheetPresentationStyle(
            sizing: .manual,
            backdropColor: R.color.colorDimBackground()!,
            headerStyle: headerStyle
        )
        return style
    }

    static var nova: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 32.0, height: 3.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.colorBottomSheetBackground()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: indicatorSize,
            indicatorColor: R.color.colorPullIndicator()!
        )
        let style = ModalSheetPresentationStyle(
            sizing: .auto(maxHeight: 500.0),
            backdropColor: R.color.colorDimBackground()!,
            headerStyle: headerStyle
        )
        return style
    }

    /// Same chrome as `nova` but with an invisible pull indicator: this sheet cannot be dragged, so
    /// drawing a drag affordance on it would be a lie. The header style is kept rather than nil
    /// because a nil header also removes the rounded bottom sheet background.
    ///
    /// `maxHeight` is a fraction of the available container height, not points — see
    /// `ModalSheetPresentationController.frameOfPresentedViewInContainerView`.
    static var novaNonDismissable: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 32.0, height: 3.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.colorBottomSheetBackground()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: indicatorSize,
            indicatorColor: .clear
        )
        let style = ModalSheetPresentationStyle(
            sizing: .auto(maxHeight: 0.9),
            backdropColor: R.color.colorDimBackground()!,
            headerStyle: headerStyle
        )
        return style
    }
}

extension ModalSheetPresentationConfiguration {
    static var novaManual: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let configuration = ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: ModalSheetPresentationStyle.novaManual,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )
        return configuration
    }

    static var nova: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let configuration = ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: ModalSheetPresentationStyle.nova,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )
        return configuration
    }

    static var novaNonDismissable: ModalSheetPresentationConfiguration {
        let appearanceAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveEaseOut]
        )
        let dismissalAnimator = BlockViewAnimator(
            duration: 0.25,
            delay: 0.0,
            options: [.curveLinear]
        )

        let configuration = ModalSheetPresentationConfiguration(
            contentAppearanceAnimator: appearanceAnimator,
            contentDissmisalAnimator: dismissalAnimator,
            style: ModalSheetPresentationStyle.novaNonDismissable,
            extendUnderSafeArea: true,
            dismissFinishSpeedFactor: 0.6,
            dismissCancelSpeedFactor: 0.6
        )
        return configuration
    }

    static var maximumContentHeight: CGFloat {
        UIScreen.main.bounds.height * 0.75
    }
}
