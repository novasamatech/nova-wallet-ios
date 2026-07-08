import Foundation

protocol AnalyticsServiceProtocol: AnyObject {
    func track(_ event: AnalyticsEvent)
    var isEnabled: Bool { get set }
}
