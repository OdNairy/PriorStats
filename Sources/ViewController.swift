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
import PKHUD

class ViewController: UIViewController, GIDSignInUIDelegate {
    let apiClient = PriorbankAPIClient.shared
    
    var cards = Variable<[Card]>([])
    let disposeBag = DisposeBag()
    
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
        
        let password = ProcessInfo.processInfo.environment["PRIOR_PASSWORD"] ?? "<password>"
        apiClient
            .login(username: "OdNairy", password: password, useCacheIfAvailable: true)
            .then { cards -> Void in
                self.cards.value = cards
            }.always {}
        
        tableView.estimatedRowHeight = 40
        tableView.rowHeight = UITableViewAutomaticDimension
        
        let transactionsObservable = cards.asObservable()
            .map { cards -> [Transaction]  in
                cards.flatMap{$0.transactions}.sorted(by: {  $0.postingDate >= $1.postingDate })
        }
        transactionsObservable
            .bind(to: tableView.rx.items(cellIdentifier: R.reuseIdentifier.transcationCell.identifier)){ _, transaction, cell in
                guard let cell = cell as? TransactionCell else {return}
                cell.titleLabel.text = self.prettyDateFormatter.string(from: transaction.postingDate)
                let localeIdentifier = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.currencyCode.rawValue : transaction.currencyISO])
                let locale = Locale(identifier: localeIdentifier)
                
                cell.priceLabel?.text = "\(transaction.amount) \(locale.currencySymbol ?? "")"
                cell.descriptionLabel.text = transaction.details
            }.addDisposableTo(disposeBag)
        //        readSpreadsheets()
        //        Observable
        //            .zip(cards.asObservable(), googleAuthReady.asObservable())
        //            .skip(1)
        //            .subscribe(onNext: { cards, authReady in
        //                guard authReady else {return}
        //                self.export(cards: cards)
        //            }).addDisposableTo(disposeBag)
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
    
    func readSpreadsheets(){
        googleAuthReady
            .asObservable()
            .skip(1)
            .subscribe(onNext: { loggedIn -> Void in
                guard loggedIn else {return}
                
                let query = GTLRSheetsQuery_SpreadsheetsValuesGet.query(withSpreadsheetId: self.spreadsheetsId, range: "'My title'!A2:I10")
                self.service.executeQuery(query) { (ticket, response, error) in
                    guard let result = response as? GTLRSheets_ValueRange else {return}
                    print(response)
                }
            })
            .addDisposableTo(disposeBag)
    }
    
    @IBAction func exportData(_ sender: UIBarButtonItem) {
        export(cards: cards.value)
    }
    
    func export(cards: [Card]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = 2
        numberFormatter.maximumFractionDigits = 2
        numberFormatter.numberStyle = .decimal
        numberFormatter.decimalSeparator = "."
        
        func transactionToValues(trans: Transaction, card: Card) -> [String]{
            
            let amountString = numberFormatter.string(from: trans.amount) ?? ""
            
            
            let accountAmountString = numberFormatter.string(from: trans.accountAmount) ?? ""
            return [dateFormatter.string(from: trans.postingDate),
                    trans.details,
                    amountString,
                    trans.currencyISO,
                    accountAmountString,
                    card.currencyCode
            ]
        }
        
        let transactions = cards
            .flatMap {card in card.transactions.map {(transaction: $0, card: card)} }
            .sorted { $0.transaction.postingDate >= $1.transaction.postingDate }
        
        let todayString = dateFormatter.string(from: Date())
        
        let values = GTLRSheets_ValueRange()
        var valuesToSend = [["Дата","Операция","Сумма","Валюта", "Оборот", "Валюта", "", "Синхронизированно:", todayString]]
        valuesToSend.append(contentsOf: transactions.map(transactionToValues))
        values.values = valuesToSend
        
        
        let query = GTLRSheetsQuery_SpreadsheetsValuesAppend.query(withObject: values, spreadsheetId: spreadsheetsId, range: "'My title'!A:A")
        query.valueInputOption = kGTLRSheetsValueInputOptionUserEntered
        query.insertDataOption = kGTLRSheetsInsertDataOptionOverwrite
        service.executeQuery(query) { (ticket, result, error) in
            if let error = error {
                print(error)
            }
            guard let response = result as? GTLRSheets_AppendValuesResponse else {return}
            print(response)
            
            let request = GTLRSheets_Request()
            request.autoResizeDimensions = GTLRSheets_AutoResizeDimensionsRequest()
            let dimensions = GTLRSheets_DimensionRange()
            dimensions.dimension = kGTLRSheets_DimensionRange_Dimension_Columns
            dimensions.startIndex = NSNumber(value: 0)
            dimensions.endIndex = NSNumber(value: 16)
            dimensions.sheetId = NSNumber(value: 1030324855)
            request.autoResizeDimensions?.dimensions = dimensions
            
            let batchRequest = GTLRSheets_BatchUpdateSpreadsheetRequest()
            batchRequest.requests = [request]
            let query = GTLRSheetsQuery_SpreadsheetsBatchUpdate.query(withObject: batchRequest, spreadsheetId: self.spreadsheetsId)
            
            self.service.executeQuery(query, completionHandler: { (_, response, error) in
                print(response)
            })
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
            //            self.output.isHidden = false
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

