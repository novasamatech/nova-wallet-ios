import RobinHood
import FirebaseCore
import FirebaseFirestore

protocol PushNotificationsSettingsSourceProtocol: SingleValueProviderSourceProtocol {
    func save(settings: PushSettings) -> CompoundOperationWrapper<Void>
    func update(token: String) -> CompoundOperationWrapper<Void>
}

final class PushNotificationsSettingsSource {
    private let uuid: String

    init(uuid: String) {
        self.uuid = uuid
        FirebaseApp.configure()
    }
}

extension PushNotificationsSettingsSource: PushNotificationsSettingsSourceProtocol {
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

    func save(settings: PushSettings) -> CompoundOperationWrapper<Void> {
        let saveSettings: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { [uuid] responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(uuid)
            try documentRef.setData(from: settings, merge: true) { error in
                if let error = error {
                    responseClosure(.failure(error))
                } else {
                    responseClosure(.success(()))
                }
            }
        }

        return .init(targetOperation: saveSettings)
    }

    func update(token: String) -> CompoundOperationWrapper<Void> {
        let updateSettings: AsyncClosureOperation<Void> = AsyncClosureOperation(cancelationClosure: {}) { [uuid] responseClosure in
            let database = Firestore.firestore()
            let documentRef = database.collection("users").document(uuid)
            try documentRef.updateData([
                "pushToken": token
            ]) { error in
                if let error = error {
                    responseClosure(.failure(error))
                } else {
                    responseClosure(.success(()))
                }
            }
        }

        return .init(targetOperation: updateSettings)
    }
}
