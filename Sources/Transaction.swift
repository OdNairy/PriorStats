//
//  Transaction.swift
//  Priorstats
//
//  Created by Roman Gardukevich on 6/16/17.
//  Copyright © 2017 Roman Gardukevich. All rights reserved.
//

import Foundation
import SwiftyJSON


/// User account in Prior system
struct UserAccount {
    
}


/// Card or Salary contract
class Card {
    var id: Int
    var cardType: String
    var currencyCode: String
    var availableAmount: Double
    
    var transactions: [Transaction]
    
    init(id: Int, cardType: String, currencyCode: String, availableAmount: Double, transactions: [Transaction]){
        self.id = id
        self.cardType = cardType
        self.currencyCode = currencyCode
        self.availableAmount = availableAmount
        self.transactions = transactions
        
        self.transactions.forEach { (transaction) in
            transaction.card = self
        }
    }
}

class Transaction {
    var postingDate: Date
//    var transactionDate: Date
//    var transactionTime: String
    var currencyISO: String
    
    var amount: Double
//    var feeAmount: Double
    var accountAmount: Double
    var details: String
    
    var card: Card?
    
    init(postingDate: Date, currencyISO: String, amount: Double, accountAmount: Double, details: String) {
        self.postingDate = postingDate
        self.currencyISO = currencyISO
        self.amount = amount
        self.accountAmount = accountAmount
        self.details = details
    }
}

extension Transaction {
    convenience init?(_ json: JSON){
        let isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.timeZone = TimeZone(abbreviation: "UTC+3")
        
        guard let postingDateString = json["transDate"].string, let postingDate = isoDateFormatter.date(from: postingDateString),
              let currencyISO = json["transCurrIso"].string,
              let amount = json["amount"].double,
              let accountAmount = json["accountAmount"].double,
              let details = json["transDetails"].string
        else { return nil }
        self.init(postingDate: postingDate, currencyISO: currencyISO, amount: amount, accountAmount: accountAmount, details: details)
    }
}
