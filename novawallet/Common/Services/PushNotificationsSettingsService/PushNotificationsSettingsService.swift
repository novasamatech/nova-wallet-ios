import RobinHood
import FirebaseCore
import FirebaseFirestore

final class PushNotificationsSettingsSource {
    private let uuid: String

    init(uuid: String) {
        self.uuid = uuid
        FirebaseApp.configure()
    }
}

extension PushNotificationsSettingsSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<PushSettings?> {
        let fetchSettings: AsyncClosureOperation<PushSettings?> = AsyncClosureOperation(cancelationClosure: {}) { [uuid] responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(uuid)

            documentRef.getDocument(as: PushSettings.self) { result in
                switch result {
                case let .success(settings):
                    responseClosure(.success(settings))
                case let .failure(error):
                    responseClosure(.failure(error))
                }
            }
        }

        return .init(targetOperation: fetchSettings)
    }
}
