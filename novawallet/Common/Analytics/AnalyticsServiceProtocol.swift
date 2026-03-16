import Foundation

protocol AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent)
    var isEnabled: Bool { get set }
}
