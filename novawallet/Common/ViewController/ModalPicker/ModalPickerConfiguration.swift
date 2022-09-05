import Foundation
import SoraUI
import UIKit

extension ModalSheetPresentationStyle {
    static var fearless: ModalSheetPresentationStyle {
        let indicatorSize = CGSize(width: 32.0, height: 3.0)
        let headerStyle = ModalSheetPresentationHeaderStyle(
            preferredHeight: 20.0,
            backgroundColor: R.color.color0x1D1D20()!,
            cornerRadius: 16.0,
            indicatorVerticalOffset: 4.0,
            indicatorSize: indicatorSize,
            indicatorColor: R.color.colorWhite32()!
        )
        let style = ModalSheetPresentationStyle(
            backdropColor: R.color.colorScrim()!,
            headerStyle: headerStyle
        )
        return style
    }
}

extension ModalSheetPresentationConfiguration {
    static var fearless: ModalSheetPresentationConfiguration {
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
            style: ModalSheetPresentationStyle.fearless,
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
