import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isConnected: Bool = true {
        didSet { onStatusChange?(isConnected) }
    }

    var onStatusChange: ((Bool) -> Void)?

    private init() {
        isConnected = (monitor.currentPath.status == .satisfied)
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = (path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }
}
