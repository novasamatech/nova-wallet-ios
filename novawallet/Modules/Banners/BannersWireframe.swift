import Foundation
import UIKit

final class BannersWireframe: BannersWireframeProtocol {
    func openActionLink(urlString: String) {
        guard
            let url = URL(string: urlString),
            UIApplication.shared.canOpenURL(url)
        else { return }

        UIApplication.shared.open(url)
    }
}
