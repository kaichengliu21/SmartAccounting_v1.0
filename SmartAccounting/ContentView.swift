import SwiftUI
import SwiftData

// 🌟 主框架升级为 3 个 Tab
struct ContentView: View {
    var body: some View {
        TabView {
            LedgerView()
                .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }
            StatsView()
                .tabItem { Label("统计", systemImage: "chart.pie.fill") }
            SettingsView() // 🌟 新增的第三个页面
                .tabItem { Label("我的", systemImage: "person.fill") }
        }
    }
}

// ==========================================
// 1. 账本明细页 (已移除左上角的清空按钮)
// ==========================================
struct LedgerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var editingTransaction: Transaction?

    var searchResults: [Transaction] {
        if searchText.isEmpty { return transactions }
        return transactions.filter {
            $0.merchant.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            $0.paymentMethod.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var searchStats: (expense: Double, income: Double, months: Double) {
        let expenses = searchResults.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let incomes = searchResults.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        guard let oldest = searchResults.last?.date, let newest = searchResults.first?.date else {
            return (expenses, incomes, 1.0)
        }
        let daysDiff = Calendar.current.dateComponents([.day], from: oldest, to: newest).day ?? 0
        let effectiveMonths = max(1.0, Double(daysDiff) / 30.44)
        return (expenses, incomes, effectiveMonths)
    }

    var body: some View {
        NavigationStack {
            List {
                if !searchText.isEmpty && !searchResults.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Text("共找到 \(searchResults.count) 笔记录").font(.caption).foregroundColor(.gray)
                                Spacer()
                                Text("跨度: 约 \(String(format: "%.1f", searchStats.months)) 月").font(.caption).foregroundColor(.gray)
                            }
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("总支出: \(String(format: "%.2f", searchStats.expense))").font(.subheadline).bold().foregroundColor(.red)
                                    Text("月均: \(String(format: "%.2f", searchStats.expense / searchStats.months))").font(.caption).foregroundColor(.red.opacity(0.8))
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("总收入: \(String(format: "%.2f", searchStats.income))").font(.subheadline).bold().foregroundColor(.green)
                                    Text("月均: \(String(format: "%.2f", searchStats.income / searchStats.months))").font(.caption).foregroundColor(.green.opacity(0.8))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                ForEach(searchResults) { transaction in
                    HStack {
                        Text(transaction.category)
                            .font(.subheadline).padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1)).cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.merchant).font(.headline)
                            HStack {
                                Text(transaction.paymentMethod)
                                Text("•")
                                Text(transaction.date.formatted(.dateTime.month().day().hour().minute()))
                            }.font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Text(transaction.isIncome ? "+\(String(format: "%.2f", transaction.amount))" : "-\(String(format: "%.2f", transaction.amount))")
                            .bold().foregroundColor(transaction.isIncome ? .green : .red)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingTransaction = transaction }
                }
                .onDelete(perform: deleteTransactions)
            }
            .navigationTitle("我的账本")
            .searchable(text: $searchText, prompt: "搜索")
            .sheet(isPresented: $showingAddSheet) { AddTransactionView() }
            .sheet(item: $editingTransaction) { tx in EditTransactionView(transaction: tx) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) { Label("添加", systemImage: "plus") }
                }
            }
        }
    }

    private func deleteTransactions(offsets: IndexSet) {
        for index in offsets { modelContext.delete(searchResults[index]) }
    }
}

// ==========================================
// 2. 🌟 新增：“我的” 设置中心
// ==========================================
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @State private var showingClearAlert = false
    @State private var showingTutorial = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("帮助与支持")) {
                    Button(action: { showingTutorial = true }) {
                        HStack {
                            Label("快捷记账配置教程", systemImage: "book.pages.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
                        }
                    }
                }

                Section(header: Text("数据管理")) {
                    HStack {
                        Label("本地账单总数", systemImage: "doc.text.magnifyingglass")
                        Spacer()
                        Text("\(transactions.count) 笔")
                            .foregroundColor(.gray)
                    }

                    // 转移到这里的清空按钮
                    Button(action: { showingClearAlert = true }) {
                        Label("清空所有账单数据", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("关于应用")) {
                    HStack {
                        Text("应用名称")
                        Spacer()
                        Text("帐记 AI").foregroundColor(.gray)
                    }
                    HStack {
                        Text("版本号")
                        Spacer()
                        Text("1.0.0").foregroundColor(.gray)
                    }
                    HStack {
                        Text("核心引擎")
                        Spacer()
                        Text("DeepSeek 大模型").foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("设置中心")
            .sheet(isPresented: $showingTutorial) { TutorialView() }
            .alert("危险操作", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) { }
                Button("确认清空", role: .destructive) { clearAllTransactions() }
            } message: {
                Text("确定要删除本地所有的记账记录吗？此操作不可逆！")
            }
        }
    }

    private func clearAllTransactions() {
        for transaction in transactions { modelContext.delete(transaction) }
        try? modelContext.save()
    }
}

// 🌟 新增：优雅的图文并茂教程页
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)

                    Text("如何解锁 AI 魔法记账？")
                        .font(.title2)
                        .bold()

                    VStack(alignment: .leading, spacing: 20) {
                        StepRow(step: "1", title: "配置系统快捷指令", desc: "在自带的「快捷指令」App中新建指令：拍摄屏幕截图 ➡️ 从图像中提取文本 ➡️ AI 智能识别账单。")
                        StepRow(step: "2", title: "绑定背板双击", desc: "前往 iPhone 设置 ➡️ 辅助功能 ➡️ 触控 ➡️ 轻点背面，将「轻点两下」设为您刚创建的指令。")
                        StepRow(step: "3", title: "一秒入账", desc: "用微信或支付宝付款完毕后，直接双击手机背面，AI 即可静默解析并自动记账。")
                        StepRow(step: "4", title: "AI 会学习你的习惯", desc: "如果分类有误，只需在明细中点击修改。大模型会自动记住该商户对应的正确分类，越用越顺手！")
                    }
                }
                .padding()
            }
            .navigationTitle("使用教程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("我学会了") { dismiss() }
                }
            }
        }
    }
}

// 辅助组件：教程排版
struct StepRow: View {
    var step: String
    var title: String
    var desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(step)
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(desc).font(.subheadline).foregroundColor(.secondary).lineSpacing(4)
            }
        }
    }
}

// ==========================================
// 3. 表单组件 (保持不变)
// ==========================================
struct EditTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var transaction: Transaction
    
    // 增加临时变量来处理金额输入
    @State private var amountString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("金额与类型")) {
                    HStack {
                        Text("金额")
                        TextField("请输入金额", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Toggle("是否为收入", isOn: $transaction.isIncome)
                }
                
                Section(header: Text("分类 (修改后AI会记住该商户的分类习惯)")) {
                    TextField("分类 (如: 🍔 餐饮)", text: $transaction.category)
                }
                
                Section(header: Text("商户识别 (若识别为平台名，请在此改为具体店名)")) {
                    TextField("具体商户名 (如: 门徒)", text: $transaction.merchant)
                }
                
                Section(header: Text("其他信息")) {
                    TextField("支付方式", text: $transaction.paymentMethod)
                    DatePicker("时间", selection: $transaction.date)
                }
            }
            .onAppear {
                // 初始化金额显示
                amountString = String(format: "%.2f", transaction.amount)
            }
            .navigationTitle("修正账单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // 保存时转换金额
                        if let val = Double(amountString) {
                            transaction.amount = val
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var merchant: String = ""
    @State private var paymentMethod: String = "微信支付"
    @State private var isIncome: Bool = false
    @State private var date: Date = Date()
    let paymentMethods = ["微信支付", "支付宝", "银行卡", "现金", "其他", "Balance", "在线支付"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("基本信息")) {
                    Picker("类型", selection: $isIncome) { Text("支出").tag(false); Text("收入").tag(true) }.pickerStyle(.segmented)
                    TextField("金额", text: $amountText).keyboardType(.decimalPad)
                    TextField("商户名", text: $merchant)
                }
                Section(header: Text("详细信息")) {
                    Picker("支付方式", selection: $paymentMethod) { ForEach(paymentMethods, id: \.self) { Text($0).tag($0) } }
                    DatePicker("时间", selection: $date)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveTransaction() }.disabled(amountText.isEmpty || merchant.isEmpty)
                }
            }
        }
    }

    private func saveTransaction() {
        guard let amount = Double(amountText) else { return }
        let category = isIncome ? "💰 收入" : CategoryManager.guessCategory(for: merchant)
        let newTx = Transaction(amount: amount, merchant: merchant, paymentMethod: paymentMethod, category: category, isIncome: isIncome, date: date)
        modelContext.insert(newTx)
        dismiss()
    }
}
