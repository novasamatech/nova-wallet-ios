import Foundation
import Foundation_iOS

final class MessageSheetMigrationBannerView: LedgerMigrationBannerView, MessageSheetContentProtocol {
    typealias ContentViewModel = LocalizableResource<LedgerMigrationBannerView.ViewModel>

    override init(frame: CGRect) {
        super.init(frame: frame)

        apply(style: .info)
    }

    func bind(messageSheetContent: ContentViewModel?, locale: Locale) {
        guard let messageSheetContent else {
            return
        }

        let viewModel = messageSheetContent.value(for: locale)
        bind(viewModel: viewModel)
    }
}
