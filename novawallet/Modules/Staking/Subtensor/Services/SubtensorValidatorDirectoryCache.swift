import Foundation

struct SubtensorValidatorDirectoryCacheEntry {
    let directory: SubtensorValidatorDirectory
    let listingReceipt: SubtensorValidatorDirectoryService.ListingReceipt
    let items: [AccountId: SubtensorValidatorDirectoryItem]
}

protocol SubtensorValidatorDirectoryCaching: AnyObject {
    var generation: UUID { get }

    func entry(for subnet: SubtensorSubnetRef) -> SubtensorValidatorDirectoryCacheEntry?

    func store(_ entry: SubtensorValidatorDirectoryCacheEntry, generation: UUID) throws

    func invalidate()
}

final class SubtensorValidatorDirectoryCache {
    private let mutex = NSLock()
    private var contextGeneration = UUID()
    private var entries: [SubtensorSubnetRef: SubtensorValidatorDirectoryCacheEntry] = [:]
}

extension SubtensorValidatorDirectoryCache: SubtensorValidatorDirectoryCaching {
    var generation: UUID {
        mutex.lock()
        defer { mutex.unlock() }
        return contextGeneration
    }

    func invalidate() {
        mutex.lock()
        contextGeneration = UUID()
        entries = [:]
        mutex.unlock()
    }

    func entry(for subnet: SubtensorSubnetRef) -> SubtensorValidatorDirectoryCacheEntry? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return entries[subnet]
    }

    func store(_ entry: SubtensorValidatorDirectoryCacheEntry, generation: UUID) throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard generation == contextGeneration else {
            throw BittensorApiError.attestationUnavailable(requestId: nil)
        }

        let subnet = entry.directory.subnet

        guard (entries[subnet]?.directory.chainBlock ?? 0) <= entry.directory.chainBlock else {
            return
        }

        entries[subnet] = entry
    }
}
