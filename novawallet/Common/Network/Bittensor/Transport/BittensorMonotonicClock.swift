import Foundation

enum BittensorMonotonicClock {
    static func now() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / TimeInterval(NSEC_PER_SEC)
    }
}
