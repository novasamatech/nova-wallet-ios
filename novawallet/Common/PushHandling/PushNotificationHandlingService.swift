protocol PushNotificationHandlingServiceProtocol: AnyObject {
    func handle(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void)
}

final class PushNotificationHandlingService {
    static let shared = PushNotificationHandlingService()

    private(set) var service: PushNotificationOpenScreenFacadeProtocol?

    func setup(service: PushNotificationOpenScreenFacadeProtocol) {
        self.service = service
    }
}

extension PushNotificationHandlingService: PushNotificationHandlingServiceProtocol {
    func handle(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void) {
        service?.handle(userInfo: userInfo, completion: completion)
    }
}
