import Foundation
import SwiftData

@Model
final class Transaction {
    var amount: Double
    var merchant: String
    var paymentMethod: String
    var category: String      // 🌟 新增：分类字段
    var isIncome: Bool
    var date: Date
    
    init(amount: Double, merchant: String, paymentMethod: String, category: String, isIncome: Bool = false, date: Date = Date()) {
        self.amount = amount
        self.merchant = merchant
        self.paymentMethod = paymentMethod
        self.category = category // 🌟 记得在这里也要赋值
        self.isIncome = isIncome
        self.date = date
    }
}
