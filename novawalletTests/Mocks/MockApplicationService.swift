import Foundation
import Cuckoo

extension MockApplicationServiceProtocol {
    func applyDefaultStub() {
        stub(self) { stub in
            stub.setup().thenDoNothing()
            stub.throttle().thenDoNothing()
        }
    }
}
