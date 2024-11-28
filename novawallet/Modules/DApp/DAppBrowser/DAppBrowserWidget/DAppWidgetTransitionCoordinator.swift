import Foundation
import UIKit

struct DAppBrowserWidgetAppearTransitionBuilder {
    var contentDisappearanceClosure: ((_ completion: @escaping () -> Void) -> ())?
    var browserAddingClosure: ((_ completion: @escaping () -> Void) -> ())?
    var widgetLayoutClosure: ((_ completion: @escaping () -> Void) -> ())?
    var contentAppearanceClosure: ((_ completion: @escaping () -> Void) -> ())?
    
    func addingContentDisappearanceClosure(_ closure: ((_ completion: @escaping () -> Void) -> ())?) -> Self {
        .init(
            contentDisappearanceClosure: closure,
            browserAddingClosure: browserAddingClosure,
            widgetLayoutClosure: widgetLayoutClosure,
            contentAppearanceClosure: contentAppearanceClosure
        )
    }
    
    func addingBrowserAddingClosure(_ closure: ((_ completion: @escaping () -> Void) -> ())?) -> Self {
        .init(
            contentDisappearanceClosure: contentDisappearanceClosure,
            browserAddingClosure: closure,
            widgetLayoutClosure: widgetLayoutClosure,
            contentAppearanceClosure: contentAppearanceClosure
        )
    }
    
    func addingWidgetLayoutClosure(_ closure: ((_ completion: @escaping () -> Void) -> ())?) -> Self {
        .init(
            contentDisappearanceClosure: contentDisappearanceClosure,
            browserAddingClosure: browserAddingClosure,
            widgetLayoutClosure: closure,
            contentAppearanceClosure: contentAppearanceClosure
        )
    }
    
    func addingContentAppearanceClosure(_ closure: ((_ completion: @escaping () -> Void) -> ())?) -> Self {
        .init(
            contentDisappearanceClosure: contentDisappearanceClosure,
            browserAddingClosure: browserAddingClosure,
            widgetLayoutClosure: widgetLayoutClosure,
            contentAppearanceClosure: closure
        )
    }
    
    func build() -> DAppWidgetTransitionCoordinator {
        DAppWidgetTransitionCoordinator(
            contentDisappearanceClosure: contentDisappearanceClosure,
            browserAddingClosure: browserAddingClosure,
            widgetLayoutClosure: contentAppearanceClosure,
            contentAppearanceClosure: contentAppearanceClosure
        )
    }
}

class DAppWidgetTransitionCoordinator {
    var contentDisappearanceClosure: ((_ completion: @escaping () -> Void) -> ())?
    var browserAddingClosure: ((_ completion: @escaping () -> Void) -> ())?
    var widgetLayoutClosure: ((_ completion: @escaping () -> Void) -> ())?
    var contentAppearanceClosure: ((_ completion: @escaping () -> Void) -> ())?
    
    init(
        contentDisappearanceClosure: ((_: @escaping () -> Void) -> Void)? = nil,
        browserAddingClosure: ((_: @escaping () -> Void) -> Void)? = nil,
        widgetLayoutClosure: ((_: @escaping () -> Void) -> Void)? = nil,
        contentAppearanceClosure: ((_: @escaping () -> Void) -> Void)? = nil
    ) {
        self.contentDisappearanceClosure = contentDisappearanceClosure
        self.browserAddingClosure = browserAddingClosure
        self.widgetLayoutClosure = widgetLayoutClosure
        self.contentAppearanceClosure = contentAppearanceClosure
    }
}
