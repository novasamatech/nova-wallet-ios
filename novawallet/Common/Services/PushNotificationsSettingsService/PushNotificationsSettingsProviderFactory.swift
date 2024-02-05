import Foundation
import RobinHood

protocol PushNotificationsSettingsProviderFactoryProtocol {
    func fetchSettings(for token: String) -> AnySingleValueProvider<PushSettings>
    func save(settings: PushSettings) -> ClosureOperation<Void>
}

final class PushNotificationsSettingsProviderFactory: PushNotificationsSettingsProviderFactoryProtocol {
    private var providers: [String: WeakWrapper] = [:]
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func fetchSettings(for token: String) -> AnySingleValueProvider<PushSettings> {
        let localKey = "push-settings-\(token)"
        if let provider = providers[localKey]?.target as? SingleValueProvider<PushSettings> {
            return AnySingleValueProvider(provider)
        }
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = storageFacade.createRepository()
        let source = PushNotificationsSettingsSource(uuid: token)

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: localKey,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[localKey] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }

    func save(settings _: PushSettings) -> ClosureOperation<Void> {
        .init {}
    }
}
