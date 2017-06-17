//
//  ViewController.swift
//  Priorstats
//
//  Created by Roman Gardukevich on 6/4/17.
//  Copyright © 2017 Roman Gardukevich. All rights reserved.
//

import UIKit
import PromiseKit
import RxSwift
import RxCocoa
import SwiftyJSON
import GoogleAPIClientForREST
import GoogleSignIn

class ViewController: UIViewController, GIDSignInUIDelegate {
    let apiClient = PriorbankAPIClient()
    
    
    var transactions = Variable<[Transaction]>([])
    let disposeBag = DisposeBag()
    
    // If modifying these scopes, delete your previously saved credentials by
    // resetting the iOS simulator or uninstall the app.
    fileprivate let scopes = [kGTLRAuthScopeSheetsSpreadsheetsReadonly, kGTLRAuthScopeSheetsSpreadsheets]
    
    fileprivate let service = GTLRSheetsService()
    let signInButton = GIDSignInButton()
    let output = UITextView()
    
    let googleAuthReady = BehaviorSubject(value: false)
    
    @IBOutlet var tableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        

        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().scopes = scopes
//        GIDSignIn.sharedInstance().signInSilently()
//        GIDSignIn.sharedInstance().signIn()
        
        let signIn = GIDSignIn.sharedInstance()!
        if signIn.hasAuthInKeychain() {
            signIn.signInSilently()
        } else {
            signIn.signIn()
        }
        
        // Add the sign-in button.
        view.addSubview(signInButton)
        
        // Add a UITextView to display output.
        output.frame = view.bounds
        output.isEditable = false
        output.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        output.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        output.isHidden = true
        view.addSubview(output);
        
        tableView.removeFromSuperview()
        apiClient
            .login(username: "OdNairy", password: "", useCacheIfAvailable: false)
            .then { transactions -> Void in
                self.transactions.value = transactions
            }.always {}
        
        tableView.estimatedRowHeight = 40
        tableView.rowHeight = UITableViewAutomaticDimension
        transactions
            .asObservable()
            .bind(to: tableView.rx.items(cellIdentifier: R.reuseIdentifier.transcationCell.identifier)){ _, transaction, cell in
                guard let cell = cell as? TransactionCell else {return}
                cell.titleLabel.text = self.prettyDateFormatter.string(from: transaction.postingDate)
                let localeIdentifier = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.currencyCode.rawValue : transaction.currencyISO])
                let locale = Locale(identifier: localeIdentifier)
                
                cell.priceLabel?.text = "\(transaction.amount) \(locale.currencySymbol ?? "")"
                cell.descriptionLabel.text = transaction.details
            }.addDisposableTo(disposeBag)
        
        Observable
            .zip(transactions.asObservable(), googleAuthReady.asObservable())
            .skip(1)
            .subscribe(onNext: { transactions, authReady in
            guard authReady else {return}
            self.add(transactions: transactions)
            
        }).addDisposableTo(disposeBag)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    lazy var prettyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // Display (in the UITextView) the names and majors of students in a sample
    // spreadsheet:
    // https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
    let spreadsheetsId = "1ej1KZpk0qrDWjdCW7dgtL5lucpIXi6owUknufg0dr4g"
    func listMajors() {
        output.text = "Getting sheet data..."
//        let spreadsheetId = "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms"
//        let range = "Class Data!A2:E"
                
        let addSheetRequest = GTLRSheets_AddSheetRequest()
        let properties = GTLRSheets_SheetProperties()
        properties.title = "My title"
            let color = GTLRSheets_Color()
            color.red = 0.75
            color.green = 0.47
            color.blue = 0.8
        
        properties.tabColor = color
        
        addSheetRequest.properties = properties
        
        let request = GTLRSheets_Request()
        request.addSheet = addSheetRequest
        
        let batchRequest = GTLRSheets_BatchUpdateSpreadsheetRequest()
        batchRequest.requests = [request]
        
        let query = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(withObject: batchRequest, spreadsheetId: spreadsheetsId)
        
        service.executeQuery(query) { (tikec, result, error) in
            if let error = error {
                print(error)
            }
            print("Done")
        }
    }
    
    
    func add(transactions: [Transaction]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        
        func transactionToValues(trans: Transaction) -> [String]{
            numberFormatter.currencyCode = trans.currencyISO
            let amountString = numberFormatter.string(from: trans.amount) ?? ""
            
            numberFormatter.currencyCode = "USD"
            let accountAmountString = numberFormatter.string(from: trans.accountAmount) ?? ""
            return [dateFormatter.string(from: trans.postingDate),
                    amountString,
                    accountAmountString,
                    trans.details]
        }
        
        let values = GTLRSheets_ValueRange()
        values.values = transactions.map(transactionToValues)

        
        let query = GTLRSheetsQuery_SpreadsheetsValuesAppend.query(withObject: values, spreadsheetId: spreadsheetsId, range: "'My title'!A:A")
        query.valueInputOption = kGTLRSheetsValueInputOptionUserEntered
        query.insertDataOption = kGTLRSheetsInsertDataOptionOverwrite
        service.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print(error)
            }
            guard let response = result as? GTLRSheets_AppendValuesResponse else {return}
            print(response)
        }
    }
    
    // Helper for showing an alert
    func showAlert(title : String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: UIAlertControllerStyle.alert
        )
        let ok = UIAlertAction(
            title: "OK",
            style: UIAlertActionStyle.default,
            handler: nil
        )
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
}

extension NumberFormatter {
    func string(from number: Double) -> String?{
        return string(from: NSNumber(value: number))
    }
}


extension ViewController: GIDSignInDelegate {
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            showAlert(title: "Authentication Error", message: error.localizedDescription)
            self.service.authorizer = nil
            self.googleAuthReady.onNext(false)
        } else {
            self.signInButton.isHidden = true
            self.output.isHidden = false
            self.service.authorizer = user.authentication.fetcherAuthorizer()
            self.googleAuthReady.onNext(true)
//            listMajors()
        }
    }
}

class TransactionCell: UITableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var priceLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
}
