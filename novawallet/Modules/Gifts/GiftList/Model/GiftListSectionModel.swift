import Foundation
import Operation_iOS

struct GiftListSectionModel {
    let section: Section
    let rows: [Row]

    var title: String? {
        switch section {
        case let .gifts(title): title
        case .header: nil
        }
    }
}

extension GiftListSectionModel {
    enum Section: Identifiable, Equatable {
        case header
        case gifts(String)

        var identifier: String {
            switch self {
            case .header: "header"
            case let .gifts(title): title
            }
        }
    }

    enum Row: Identifiable, Equatable {
        case header(Locale)
        case gift(GiftListGiftViewModel)

        var identifier: String {
            switch self {
            case let .header(locale):
                locale.identifier
            case let .gift(viewModel):
                viewModel.identifier
            }
        }
    }
}
