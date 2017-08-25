import Foundation
import CoreData

class CoreDataStackManager {
    
    fileprivate var container: NSPersistentContainer
    fileprivate var bgContext: NSManagedObjectContext!
    fileprivate var rootContext: NSManagedObjectContext!
    
    var mainContext: NSManagedObjectContext!
    
    init(modelName: String, completion: @escaping () -> ())  {
        container = NSPersistentContainer(name: modelName)
        container.loadPersistentStores() { [unowned self] (description, error) in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
            
            self.rootContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            self.rootContext.persistentStoreCoordinator = self.container.persistentStoreCoordinator
            self.rootContext.mergePolicy = NSMergePolicy.overwrite
            
            self.bgContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
            self.mainContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            
            self.mainContext.parent = self.rootContext
            self.bgContext.parent = self.mainContext
            
            completion()
        }
    }
    
    func saveInBackground(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = bgContext!
        context.perform { [unowned self] in
            block(context)
            self.save()
        }
    }
    
    func saveInBackground<T>(_ block: @escaping (NSManagedObjectContext) -> T?, completion: QueuedCompletion<T>) {
        let context = bgContext!
        
        context.performAndWait { [unowned self] in
            let result = block(context)
            self.save()
            completion.scheduleCompletion(with: result)
        }
    }
    
    func readInBackground<T>(_ block: @escaping (NSManagedObjectContext) -> T?, completion: QueuedCompletion<T>) {
        let context = bgContext!
        
        context.perform {
            let result = block(context)
            completion.scheduleCompletion(with: result)
        }
    }

    
    private func save() {
        bgContext.perform { [unowned self] in
            try? self.bgContext.save()
            
            self.mainContext.perform {
                try? self.mainContext.save()
                
                self.rootContext.perform {
                    try? self.rootContext.save()
                }
            }
        }
    }
    
}
