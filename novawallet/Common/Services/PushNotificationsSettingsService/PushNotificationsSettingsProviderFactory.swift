import Foundation
import RobinHood

protocol PushNotificationsSettingsServiceProtocol {
    func settingsProvider(for documentId: String) -> AnySingleValueProvider<PushSettings>
    func save(documentId: String, settings: PushSettings) -> CompoundOperationWrapper<Void>
}

final class PushNotificationsSettingsService: PushNotificationsSettingsServiceProtocol {
    private var providers: [String: WeakWrapper] = [:]
    let storageFacade: StorageFacadeProtocol

    init(storageFacade: StorageFacadeProtocol) {
        self.storageFacade = storageFacade
    }

    func settingsProvider(for documentId: String) -> AnySingleValueProvider<PushSettings> {
        let localKey = "push-settings-\(documentId)"
        if let provider = providers[localKey]?.target as? SingleValueProvider<PushSettings> {
            return AnySingleValueProvider(provider)
        }
        let repository: CoreDataRepository<SingleValueProviderObject, CDSingleValue> = storageFacade.createRepository()
        let source = PushNotificationsSettingsSource(uuid: documentId)

        let singleValueProvider = SingleValueProvider(
            targetIdentifier: localKey,
            source: AnySingleValueProviderSource(source),
            repository: AnyDataProviderRepository(repository)
        )

        providers[localKey] = WeakWrapper(target: singleValueProvider)

        return AnySingleValueProvider(singleValueProvider)
    }

    func save(documentId: String, settings: PushSettings) -> CompoundOperationWrapper<Void> {
        PushNotificationsSettingsSource(uuid: documentId).save(settings: settings)
    }
}
