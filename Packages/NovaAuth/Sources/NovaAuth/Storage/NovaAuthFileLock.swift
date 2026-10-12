import Foundation
import Darwin

/// Bounds contention across both threads and app/extension processes; never proceeds unlocked.
final class NovaAuthFileLock: NovaAuthFileLockProtocol {
    private let containerURL: URL
    private let timeout: TimeInterval
    private let mutex = NSLock()

    init(containerURL: URL, timeout: TimeInterval = 0.25) {
        self.containerURL = containerURL
        self.timeout = timeout
    }

    func withLock<T>(_ body: () throws -> T) throws -> T {
        guard containerURL.isFileURL, timeout.isFinite, timeout > 0, timeout <= 5 else {
            throw NovaAuthError.storageUnavailable
        }
        let start = DispatchTime.now().uptimeNanoseconds
        let limit = UInt64(timeout * 1_000_000_000)
        try wait(start: start, limit: limit) { self.mutex.try() }
        defer { mutex.unlock() }
        let descriptor = try openLockFile()
        defer { close(descriptor) }
        try wait(start: start, limit: limit) {
            if flock(descriptor, LOCK_EX | LOCK_NB) == 0 { return true }
            guard errno == EWOULDBLOCK || errno == EINTR else { throw NovaAuthError.storageUnavailable }
            return false
        }
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}

private extension NovaAuthFileLock {
    func wait(start: UInt64, limit: UInt64, attempt: () throws -> Bool) throws {
        repeat {
            if try attempt() { return }
            let now = DispatchTime.now().uptimeNanoseconds
            guard now >= start, now - start < limit else { throw NovaAuthError.storageUnavailable }
            var interval = timespec(tv_sec: 0, tv_nsec: 1_000_000)
            nanosleep(&interval, nil)
        } while true
    }

    func openLockFile() throws -> Int32 {
        let directory = containerURL.appendingPathComponent("NovaAuth", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700,
                             .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
        } catch { throw NovaAuthError.storageUnavailable }
        var info = stat()
        guard lstat(directory.path, &info) == 0, info.st_mode & S_IFMT == S_IFDIR else {
            throw NovaAuthError.storageUnavailable
        }
        let path = directory.appendingPathComponent("profile3.lock").path
        let descriptor = open(path, O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw NovaAuthError.storageUnavailable }
        var fileInfo = stat()
        guard fstat(descriptor, &fileInfo) == 0, fileInfo.st_mode & S_IFMT == S_IFREG,
              fchmod(descriptor, 0o600) == 0 else {
            close(descriptor)
            throw NovaAuthError.storageUnavailable
        }
        return descriptor
    }
}
