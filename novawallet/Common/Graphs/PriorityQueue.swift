import Foundation

struct PriorityQueue<T> {
    private var heap: [T]
    private let ordered: (T, T) -> Bool

    var isEmpty: Bool {
        heap.isEmpty
    }

    init(sort: @escaping (T, T) -> Bool) {
        heap = []
        ordered = sort
    }

    mutating func push(_ value: T) {
        heap.append(value)
        siftUp(heap.count - 1)
    }

    mutating func pop() -> T? {
        if heap.isEmpty { return nil }
        heap.swapAt(0, heap.count - 1)
        let value = heap.removeLast()
        siftDown(0)
        return value
    }

    private mutating func siftUp(_ index: Int) {
        var index = index
        while index > 0, ordered(heap[index], heap[(index - 1) / 2]) {
            heap.swapAt(index, (index - 1) / 2)
            index = (index - 1) / 2
        }
    }

    private mutating func siftDown(_ index: Int) {
        let count = heap.count

        var index = index
        while 2 * index + 1 < count {
            let leftChild = 2 * index + 1
            let rightChild = 2 * index + 2

            let preferredChild = if rightChild < count, ordered(heap[rightChild], heap[leftChild]) {
                rightChild
            } else {
                leftChild
            }

            if ordered(heap[index], heap[preferredChild]) { return }
            heap.swapAt(index, preferredChild)
            index = preferredChild
        }
    }
}
