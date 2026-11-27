import Foundation

/// Time for measuring intervals inside one launch. It doesn't follow the changes of the device clock
/// and keeps counting while the device sleeps, so an interval is as long as it was for the user.
enum MonotonicClock {
    static func now() -> TimeInterval {
        TimeInterval(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / TimeInterval(NSEC_PER_SEC)
    }
}
