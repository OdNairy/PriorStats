import Foundation
import RxSwift

class DBManager {
    static let instance = DBManager()
    
    var isInitialized = Variable<Bool>(false)
    var stack: CoreDataStackManager!
    
    private init() {
        stack = CoreDataStackManager(modelName: "PriorStats") { [weak self] in
            self?.isInitialized.value = true
        }
    }
    
}
