import Foundation
import Operation_iOS

protocol RaiseProviderFactoryProtocol {
    func createCardsProvider() -> AnyDataProvider<RaiseCardLocal>
}

final class RaiseProviderFactory {
    enum LocalIdentifier {
        static let raiseCards = "raise-cards"
    }

    let operationFactory: RaiseOperationFactoryProtocol

    private var providers: [String: WeakWrapper] = [:]

    init(operationFactory: RaiseOperationFactoryProtocol) {
        self.operationFactory = operationFactory
    }

    private func clearIfNeeded() {
        providers = providers.filter { $0.value.target != nil }
    }
}

extension RaiseProviderFactory: RaiseProviderFactoryProtocol {
    func createCardsProvider() -> AnyDataProvider<RaiseCardLocal> {
        clearIfNeeded()

        if let provider = providers[LocalIdentifier.raiseCards]?.target as? AnyDataProvider<RaiseCardLocal> {
            return provider
        }

        let source = RaiseCardsProviderSource(operationFactory: operationFactory)
        let repository = InMemoryDataProviderRepository<RaiseCardLocal>()
        let provider = DataProvider(
            source: AnyDataProviderSource(source),
            repository: AnyDataProviderRepository(repository),
            updateTrigger: DataProviderEventTrigger.onAddObserver
        )

        let anyProvider = AnyDataProvider(provider)

        providers[LocalIdentifier.raiseCards] = .init(target: anyProvider)

        return anyProvider
    }
}
