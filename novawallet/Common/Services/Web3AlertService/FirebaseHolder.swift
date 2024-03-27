import FirebaseCore
import FirebaseFirestore
import FirebaseAppCheck

final class FirebaseHolder {
    static let shared = FirebaseHolder()

    private(set) var isConfigured: Bool = false
    private let mutex = NSLock()

    func configureApp() {
        defer {
            mutex.unlock()
        }
        mutex.lock()

        guard !isConfigured else {
            return
        }

        #if F_APPCHECK_DEBUG
            let providerFactory = AppCheckDebugProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        #else
            let providerFactory = FirebaseAppCheckProviderFactory()
            AppCheck.setAppCheckProviderFactory(providerFactory)
        #endif

        FirebaseApp.configure()
        isConfigured = true
    }
}
