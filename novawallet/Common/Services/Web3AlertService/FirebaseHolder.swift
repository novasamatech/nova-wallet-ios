import FirebaseCore
import FirebaseFirestore

final class FirebaseHolder {
    static let shared = FirebaseHolder()

    private(set) var isConfigured: Bool = false
    private let mutex = NSLock()

    func configureApp() {
        defer {
            mutex.unlock()
        }
        mutex.unlock()

        guard !isConfigured else {
            return
        }
        FirebaseApp.configure()
        isConfigured = true
    }
}
