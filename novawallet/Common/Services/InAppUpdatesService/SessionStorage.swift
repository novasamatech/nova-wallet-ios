import Keystore_iOS

protocol SessionStorageProtocol: AnyObject {
    var inAppUpdatesWasShown: Bool { get set }
}

final class SessionStorage: SessionStorageProtocol {
    static let shared = SessionStorage()

    @Atomic(defaultValue: false)
    var inAppUpdatesWasShown: Bool

    private init() {}
}
