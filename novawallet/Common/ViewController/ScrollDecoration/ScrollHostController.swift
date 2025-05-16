import UIKit

protocol ScrollViewTrackingProtocol: AnyObject {
    func trackScrollViewDidChangeOffset(_ newOffset: CGPoint)
}

protocol ScrollViewHostProtocol: AnyObject {
    var initialTrackingInsets: UIEdgeInsets { get }

    var scrollViewTracker: ScrollViewTrackingProtocol? { get set }
}

typealias ScrollViewHostControlling = ControllerBackedProtocol & ScrollViewHostProtocol

typealias ScrollViewHostAndDecoratorControlling = ControllerBackedProtocol & ScrollViewHostProtocol & ScrollDecorationProviding
