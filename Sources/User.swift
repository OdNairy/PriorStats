import Foundation
import CoreData

struct User{
    var id: Int = 0
    var fullname: String = ""
}

extension User {
    static func fromUserRecord(record: UserRecord) -> User{
        return User(id: Int(record.id), fullname: record.fullname ?? "")
    }
    
    func toUserRecord(context: NSManagedObjectContext) -> UserRecord {
        let record = UserRecord(context: context)
        record.id = Int32(id)
        record.fullname = fullname
        return record
    }
}



