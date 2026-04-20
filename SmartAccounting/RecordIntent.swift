import AppIntents
import SwiftData
import Foundation

// 1. 定义一个快捷指令操作
struct RecordExpenseIntent: AppIntent {
    // 在快捷指令中显示的名称
    static var title: LocalizedStringResource = "记录账单"
    static var description = IntentDescription("快速向记账本中添加一笔新消费")

    // 快捷指令需要用户（或自动化）提供的参数
    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "商户名")
    var merchant: String
    
    @Parameter(title: "支付方式")
    var paymentMethod: String

    // 快捷指令执行时的核心逻辑
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let schema = Schema([Transaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = container.mainContext
        
        // 🌟 调用大脑，自动推断分类 (这里的 merchant 和 amount 是快捷指令传过来的变量，所以不会报错)
        let autoCategory = CategoryManager.guessCategory(for: merchant)
        
        // 生成一条新的账单记录 (加入 category)
        let newTransaction = Transaction(amount: amount, merchant: merchant, paymentMethod: paymentMethod, category: autoCategory, isIncome: false, date: Date())
        
        // 存入数据库并保存
        context.insert(newTransaction)
        try context.save()
        
        return .result(dialog: "记账成功！已记录\(merchant)消费 \(amount) 元。")
    }
}

// 2. 告诉 iOS 系统，我的 App 提供了哪些快捷指令
struct SmartAccountingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "用 \(.applicationName) 记账"
            ],
            shortTitle: "快速记账",
            systemImageName: "yensign.circle"
        )
    }
}
