import Foundation

final class SubtensorSessionCache<Model> {
    private struct Entry {
        let model: Model
        let updatedAt: Date
    }

    let timeToLive: TimeInterval

    private let mutex = NSLock()
    private var entry: Entry?

    init(timeToLive: TimeInterval = TimeInterval(15).secondsFromMinutes) {
        self.timeToLive = timeToLive
    }

    func freshModel() -> Model? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let entry, Date().timeIntervalSince(entry.updatedAt) < timeToLive else {
            return nil
        }

        return entry.model
    }

    func store(_ model: Model) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        entry = Entry(model: model, updatedAt: Date())
    }
}
