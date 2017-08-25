import CoreData
import RxSwift

extension DBManager {
    func fetchUsers(completion: @escaping ([User]) -> ()){
        let fetchRequest = NSFetchRequest<UserRecord>(entityName: "UserRecord")
        
        let completionOnMain = QueuedCompletion<[UserRecord]>(queueType: .main) { list in
            guard let list = list else {
                return
            }
            
            completion(list.map(User.fromUserRecord))
        }
        
        stack.readInBackground({ context -> [UserRecord] in
            do {
                return try context.fetch(fetchRequest)
            } catch {
                print("fetching failed with error \(error)")
                return []
            }
        }, completion: completionOnMain)
    }
    
    func save(user: User){
        stack.saveInBackground { context in
            context.insert(user.toUserRecord(context: context))
        }
    }
    
    func save(string: String){
        print("Do nothing")
    }
}

