//
//  MinHeap.swift
//  DayPlanner (PlanDay)
//
//  A generic binary min-heap (pure Swift value type).
//  Used by RouteService to select the nearest unvisited stop
//  in O(log n) per extraction instead of O(n) linear scan,
//  reducing nearest-neighbour route optimisation from O(n²) to O(n log n).
//
//  Binary min-heap invariant: heap[i] ≤ heap[2i+1] and heap[i] ≤ heap[2i+2]
//  Insert: append + sift up   — O(log n)
//  extractMin: swap root with last, remove last, sift down — O(log n)
//

struct MinHeap<T> {

    private var heap: [T] = []
    private let comparator: (T, T) -> Bool

    init(comparator: @escaping (T, T) -> Bool) {
        self.comparator = comparator
    }

    var isEmpty: Bool { heap.isEmpty }
    var count: Int    { heap.count }

    // MARK: - Insert

    mutating func insert(_ element: T) {
        heap.append(element)
        siftUp(from: heap.count - 1)
    }

    // MARK: - Extract minimum

    mutating func extractMin() -> T? {
        guard !heap.isEmpty else { return nil }
        if heap.count == 1 { return heap.removeLast() }
        let min = heap[0]
        heap[0] = heap.removeLast()
        siftDown(from: 0)
        return min
    }

    // MARK: - Peek

    var min: T? { heap.first }

    // MARK: - Private sift operations

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard comparator(heap[child], heap[parent]) else { break }
            heap.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left  = 2 * parent + 1
            let right = 2 * parent + 2
            var candidate = parent

            if left  < heap.count && comparator(heap[left],  heap[candidate]) { candidate = left  }
            if right < heap.count && comparator(heap[right], heap[candidate]) { candidate = right }

            guard candidate != parent else { break }
            heap.swapAt(parent, candidate)
            parent = candidate
        }
    }
}
