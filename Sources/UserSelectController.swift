import UIKit
import RxSwift

class UserSelectController: UIViewController{
    let db = DBManager.instance
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        db.fetchUsers { (users) in
            
        }
        // Check existing users
        
        // Autologin?
        
        // If no users exist - show login-password screen
        
        //
    }
}
