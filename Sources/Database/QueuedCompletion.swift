import Foundation

final class QueuedCompletion<T> {
    
    enum QueueType {
        case main, background
    }
    
    fileprivate var targetQueue: DispatchQueue!
    fileprivate var completion: (T?) -> Void
    
    convenience init(queueType: QueueType, completion: @escaping (T?) -> Void) {
        let queue: DispatchQueue
        
        switch queueType {
        case .background:
            queue = DispatchQueue.global(qos: .default)
            
        case .main:
            queue = DispatchQueue.main
        }
        
        self.init(targetQueue: queue, completion: completion)
    }
    
    required init(targetQueue: DispatchQueue, completion: @escaping (T?) -> Void) {
        self.targetQueue = targetQueue
        self.completion = completion
    }
    
    func scheduleCompletion(with data: T?) {
        targetQueue.async {
            self.completion(data)
            self.targetQueue = nil
        }
    }
}
