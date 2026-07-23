import Foundation

final class WalletOperationCancellation {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var isCancelled = false

    func setTask(_ task: Task<Void, Never>) {
        self.lock.lock()
        if self.isCancelled {
            self.lock.unlock()
            task.cancel()
        } else {
            self.task = task
            self.lock.unlock()
        }
    }

    func cancel() {
        self.lock.lock()
        self.isCancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}
