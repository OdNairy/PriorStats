//
//  PriorbankAPI.swift
//  Priorstats
//
//  Created by Roman Gardukevich on 6/4/17.
//  Copyright © 2017 Roman Gardukevich. All rights reserved.
//

import Foundation
import Alamofire
import PromiseKit
import SwiftyJSON
import CryptoSwift
import SwiftDate


class PriorbankAPIClient {
    private var session: String?
    private var token: String?
    private var clientSecret: String?
    
    @discardableResult
    func login(username: String, password: String, useCacheIfAvailable: Bool = true) -> Promise<[Transaction]>{
//        Promise { (success, failure) in
//
//        }
        let api = PriorbankAPI()
        
        var mobileTokens: PriorbankAPI.MobileTokenData?
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("transactions.json")
        let data = try? Data.init(contentsOf: path)
        if let data = data, useCacheIfAvailable == true {
            let json = JSON(data: data)
            let transactionsJSON = json.arrayValue.flatMap{$0["contract"]["account"]["transCardList"].arrayValue.flatMap{ $0["transactionList"].arrayValue }}
            let transactions = transactionsJSON.flatMap(Transaction.init).sorted(by: {  $0.postingDate >= $1.postingDate })
            return Promise(value: transactions)
        }
        
        let transactionsPromise: Promise<JSON> = api.mobileToken().then { tokens -> Promise<PriorbankAPI.SaltData> in
            self.clientSecret = tokens.secret
            self.token = tokens.token
            mobileTokens = tokens
            return api.getServerSalt(token: tokens.token, secret: tokens.secret, username: username)
        }.then { salt -> Promise<PriorbankAPI.LoginData> in
            guard let secret = self.clientSecret, let token = self.token else {throw "Secret and Token should exist on login stage"}
            
            return api.login(username: username, password: password, salt: salt, token: token, secret: secret)
        }.then { loginData  in
            print(loginData)
            let toDate = Date()
            let fromDate = (Date() - 3.months + 1.days).startOfDay
            return api.cardsHistory(fromDate: fromDate, toDate: toDate, session: loginData.session, token: loginData.token)
        }
        
        return transactionsPromise.then{ json -> [Transaction] in
            try json.rawData().write(to: path)
            
            
            let transactionsJSON = json.arrayValue.flatMap{$0["contract"]["account"]["transCardList"].arrayValue.flatMap{ $0["transactionList"].arrayValue }}
            let transactions = transactionsJSON.flatMap(Transaction.init)
            
            return transactions.sorted(by: {  $0.postingDate >= $1.postingDate })
        }
        
    }
}
extension String: Error {}

class PriorbankAPI {
    
    class func authorizationHeaderValue(_ token: String) -> String {
        return "bearer \(token)"
    }
    
    typealias MobileTokenData = (token: String, secret: String)
    func mobileToken() -> Promise<MobileTokenData> {
        return Promise { (success, failure) in
            request("https://prior.by/api3/api/Authorization/MobileToken", method: .get)
            .validate()
            .responseData(completionHandler: { (dataResponse) in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                let json = JSON(data: data)
                success((token: json["access_token"].stringValue, secret: json["client_secret"].stringValue))
            })
        }
        
    }
    
    typealias SaltData = String
    func getServerSalt(token: String, secret: String, username: String) -> Promise<SaltData> {
        return Promise { (success, failure) in
            
            request("https://prior.by/api3/api/Authorization/GetSalt",
                    method: .post,
                    parameters: ["lang":"RUS", "login":username],
                    encoding: JSONEncoding.default,
                    headers: ["Authorization":PriorbankAPI.authorizationHeaderValue(token), "client_id":secret])
            .validate()
            .responseData{ dataResponse in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                
                let json = JSON(data: data)
                guard let salt = json["result"]["salt"].string, salt == "" else {
                    failure("Salt should be \"\" but got \(json["result"]["salt"].string ?? "<no value>")")
                    return
                }
                
                success(salt)
            }
        }
    }
    
    typealias LoginData = (token: String, session: String)
    func login(username: String, password: String, salt: String, token: String, secret: String) -> Promise<LoginData> {
        return Promise(resolvers: { (success, failure) in
            let hashedPassword = (password).sha512()
            
            request("https://prior.by/api3/api/Authorization/Login",
                    method: .post,
                    parameters: ["login":username, "lang":"RUS", "password":hashedPassword],
                    encoding: JSONEncoding.default,
                    headers: ["Authorization":PriorbankAPI.authorizationHeaderValue(token), "client_id":secret, "User-Agent":"Paw/3.1 (Macintosh; OS X/10.12.5) GCDHTTPRequest"] )
            .validate()
            .responseData{ dataResponse in
                guard let data = dataResponse.data else {
                    failure(dataResponse.error!)
                    return
                }
                
                let json = JSON(data: data)
                
                let successRoot = json["result"]
                let newToken = successRoot["access_token"].stringValue
                let session = successRoot["userSession"].stringValue
                
                success((token: newToken, session: session))
            }
        })
    }
    
    typealias TransactionsHistory = JSON
    func cardsHistory(fromDate: Date, toDate: Date, session: String, token: String) -> Promise<JSON>{
        return Promise(resolvers: { (success, failure) in
            let dateFormatter = ISO8601DateFormatter()
            
            let fromDateString = dateFormatter.string(from: fromDate)
            let toDateString = dateFormatter.string(from: toDate)
            request("https://prior.by/api3/api/Cards/CardDesc",
                    method: .post,
                    parameters: ["dateFrom":fromDateString, "dateFromSpecified":true,
                                 "dateTo":toDateString, "dateToSpecified":true,
                                 "userSession":session,
                                 "ids":[]],
                    encoding: JSONEncoding.default,
                    headers: ["Authorization":PriorbankAPI.authorizationHeaderValue(token)/*, "User-Agent":"Paw/3.1 (Macintosh; OS X/10.12.5) GCDHTTPRequest"*/] )
                .validate()
                .response(completionHandler: { (resp) in
                    
                })
                .responseData{ dataResponse in
                    guard let data = dataResponse.data else {
                        failure(dataResponse.error!)
                        return
                    }
                    
                    let json = JSON(data: data)
                    print(json["success"].stringValue)
                    let successRoot = json["result"]
                    success(successRoot)
            }
        })
    }
    
    
    
}
