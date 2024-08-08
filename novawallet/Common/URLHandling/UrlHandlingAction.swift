import Foundation

enum UrlHandlingAction {
    case open(screen: String)
    case create(screen: String)

    init?(from url: URL) {
        let pathComponents = url.pathComponents

        guard pathComponents.count >= 3 else { return nil }

        let action = pathComponents[1].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let screen = pathComponents[2].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        let handlingAction: UrlHandlingAction? = switch action {
        case "open":
            .open(screen: screen)
        case "create":
            .create(screen: screen)
        default:
            nil
        }

        guard let handlingAction else { return nil }

        self = handlingAction
    }
}
