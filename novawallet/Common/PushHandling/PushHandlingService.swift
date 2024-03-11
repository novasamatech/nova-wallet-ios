protocol PushHandlingServiceProtocol: AnyObject {
    func handle(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void)
}

final class PushHandlingService {
    static let shared = PushHandlingService()

    private(set) var service: OpenPushScreenServiceProtocol?

    func setup(service: OpenPushScreenServiceProtocol) {
        self.service = service
    }
}

extension PushHandlingService: PushHandlingServiceProtocol {
    func handle(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void) {
        service?.handle(userInfo: userInfo, completion: completion)
    }
}
