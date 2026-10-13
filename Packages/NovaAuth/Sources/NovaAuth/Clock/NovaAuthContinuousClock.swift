import Foundation
import Darwin

struct NovaAuthContinuousClock: NovaAuthClockProtocol {
    private let read: () throws
        -> (ticks: UInt64, numerator: UInt32, denominator: UInt32, seconds: Int64, microseconds: Int32)

    init() { read = Self.readSystem }

    func now() throws -> NovaAuthTime {
        do {
            let sample = try read()
            guard sample.numerator > 0, sample.denominator > 0, sample.seconds > 0,
                  (0 ..< 1_000_000).contains(sample.microseconds) else { throw NovaAuthError.clockUnavailable }
            let seconds = Double(sample.ticks) * Double(sample.numerator) / Double(sample.denominator) / 1_000_000_000
            guard seconds.isFinite, seconds >= 0 else { throw NovaAuthError.clockUnavailable }
            return NovaAuthTime(bootID: "\(sample.seconds):\(sample.microseconds)", continuousSeconds: seconds)
        } catch { throw NovaAuthError.clockUnavailable }
    }

    private static func readSystem() throws -> (UInt64, UInt32, UInt32, Int64, Int32) {
        var timebase = mach_timebase_info_data_t()
        var boot = timeval()
        var length = MemoryLayout<timeval>.size
        guard mach_timebase_info(&timebase) == KERN_SUCCESS,
              sysctlbyname("kern.boottime", &boot, &length, nil, 0) == 0,
              length == MemoryLayout<timeval>.size else { throw NovaAuthError.clockUnavailable }
        return (mach_continuous_time(), timebase.numer, timebase.denom, Int64(boot.tv_sec), Int32(boot.tv_usec))
    }
}

struct NovaAuthSystemRandom: NovaAuthRandomProtocol {
    func makeClientID() -> String { UUID().uuidString.lowercased() }
    func unitInterval() -> Double { Double.random(in: 0 ... 1) }
}
