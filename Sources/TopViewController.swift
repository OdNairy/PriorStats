import UIKit
import RxSwift
import SwiftDate

class TopViewController: UIViewController {
    @IBOutlet var tableView: UITableView!
    private let client = PriorbankAPIClient.shared
    
    let disposeBag = DisposeBag()
    var transactions: Variable<[[Transaction]]> = Variable([])
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
        
        client.lastData.asObservable()
            .map({ cards in
                cards.flatMap{$0.transactions}
                
            })
            .map(self.convert)
            .subscribe(onNext: { trans -> Void in
                self.transactions.value = trans
            })
            .addDisposableTo(disposeBag)
        
        transactions.asObservable()
            .subscribe(onNext: { groupedTransactions -> Void in
                self.tableView.reloadData()
            })
            .addDisposableTo(disposeBag)
    }
    
    func convert(transactions: [Transaction]) -> [[Transaction]]{
        var grouped: [[Transaction]] = []
        let transactions = transactions.sorted { (lhs, rhs) -> Bool in
            return lhs.postingDate >= rhs.postingDate
        }
        
        var lastTransaction: Transaction?
        for transaction in transactions {
            defer { lastTransaction = transaction }
            guard let lastTransaction = lastTransaction else {
                grouped.append([transaction])
                continue
            }
            if transaction.postingDate.inDefaultRegion().isDateIsTheSameMonth(lastTransaction.postingDate.inDefaultRegion()) {
                guard var collection = grouped.popLast() else {continue}
                collection.append(transaction)
                grouped.append(collection)
            } else {
                if let collection = grouped.popLast() {
                    let newCollection = collection.sorted(by: { (lhs, rhs) -> Bool in
                        abs(lhs.accountAmount) > abs(rhs.accountAmount)
                    })
                    grouped.append(newCollection)
                }
                grouped.append([transaction])
            }
        }
        
        return grouped
    }
}

extension DateInRegion {
    func isDateIsTheSameMonth(_ date: DateInRegion) -> Bool{
        return self.month == date.month && self.year == date.year
    }
}

extension TopViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.transactions.value.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.transactions.value[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.cell, for: indexPath)!
        let transaction = self.transactions.value[indexPath.section][indexPath.row]
        
        cell.textLabel?.text = transaction.details
        cell.detailTextLabel?.text = "\(transaction.accountAmount) \(transaction.card?.currencyCode ?? "$")"
        
        return cell
    }
}

extension TopViewController: UITableViewDelegate{
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let transaction = self.transactions.value[section].first else {return nil}
        
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL, yyyy"
        return formatter.string(from: transaction.postingDate).capitalized
    }
}
