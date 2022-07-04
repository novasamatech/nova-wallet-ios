import Foundation

enum MissingRuntimeEntryStrategy<T> {
    case emitError
    case defaultValue(T?)
}

struct StorageProviderSourceFallback<T> {
    let usesRuntimeFallback: Bool
    let missingEntryStrategy: MissingRuntimeEntryStrategy<T>
}
