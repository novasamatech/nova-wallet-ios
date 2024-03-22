import FirebaseCore
import FirebaseFirestore

final class FirebaseHolder {
    static let shared = FirebaseHolder()

    #if F_RELEASE
        static let configPath = R.file.googleServiceInfoProductionPlist()!
    #else
        static let configPath = R.file.googleServiceInfoDevPlist()!
    #endif

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

        guard let options = FirebaseOptions(contentsOfFile: Self.configPath.path) else {
            fatalError("Can't create firebase config")
        }

        FirebaseApp.configure(options: options)
        isConfigured = true
    }
}
