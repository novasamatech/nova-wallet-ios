import Foundation
import UIKit

final class MessageSheetTimerWithBannerView: GenericPairValueView<
    MessageSheetMigrationBannerView,
    TxExpirationMessageSheetTimerLabel
>, MessageSheetContentProtocol {
    typealias ContentViewModel = MessageSheetTimerWithBannerView.ViewModel

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    func configure() {
        makeVertical()

        spacing = 32
    }

    func bind(messageSheetContent: ContentViewModel?, locale: Locale) {
        sView.bind(messageSheetContent: messageSheetContent?.timerViewModel, locale: locale)
        fView.bind(messageSheetContent: messageSheetContent?.bannerViewModel, locale: locale)
    }
}

extension MessageSheetTimerWithBannerView {
    struct ViewModel {
        let timerViewModel: TxExpirationMessageSheetTimerLabel.ContentViewModel
        let bannerViewModel: MessageSheetMigrationBannerView.ContentViewModel
    }
}
