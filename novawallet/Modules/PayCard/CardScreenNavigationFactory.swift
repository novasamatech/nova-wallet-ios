import Foundation

protocol CardScreenNavigationFactoryProtocol {
    func createCardScreen(using navigation: PayCardNavigation?) -> ControllerBackedProtocol?
}

final class CardScreenNavigationFactory {}

private extension CardScreenNavigationFactory {
    func createMercuryoCardScreen() -> ControllerBackedProtocol? {
        PayCardViewFactory.createView()
    }
}

extension CardScreenNavigationFactory: CardScreenNavigationFactoryProtocol {
    func createCardScreen(using navigation: PayCardNavigation?) -> ControllerBackedProtocol? {
        guard let navigation else { return createMercuryoCardScreen() }

        return switch navigation {
        case .mercuryo:
            createMercuryoCardScreen()
        }
    }
}
