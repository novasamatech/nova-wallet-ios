import Foundation

struct SubtensorValidatorDirectoryCacheEntry {
    let directory: SubtensorValidatorDirectory
    let listingReceipt: SubtensorValidatorDirectoryService.ListingReceipt
    let items: [AccountId: SubtensorValidatorDirectoryItem]
}

protocol SubtensorValidatorDirectoryCaching: AnyObject {
    func entry(for subnet: SubtensorSubnetRef) -> SubtensorValidatorDirectoryCacheEntry?

    func store(_ entry: SubtensorValidatorDirectoryCacheEntry)
}

final class SubtensorValidatorDirectoryCache {
    private let mutex = NSLock()
    private var entries: [SubtensorSubnetRef: SubtensorValidatorDirectoryCacheEntry] = [:]
}

extension SubtensorValidatorDirectoryCache: SubtensorValidatorDirectoryCaching {
    func entry(for subnet: SubtensorSubnetRef) -> SubtensorValidatorDirectoryCacheEntry? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return entries[subnet]
    }

    func store(_ entry: SubtensorValidatorDirectoryCacheEntry) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let subnet = entry.directory.subnet

        guard (entries[subnet]?.directory.chainBlock ?? 0) <= entry.directory.chainBlock else {
            return
        }

        entries[subnet] = entry
    }
}
