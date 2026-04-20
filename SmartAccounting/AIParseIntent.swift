import AppIntents
import SwiftData
import Foundation

struct AIParseIntent: AppIntent {
    static var title: LocalizedStringResource = "AI 智能识别账单"
    static var description = IntentDescription("调用大模型解析截图，并自动学习用户的分类习惯")

    @Parameter(title: "截图文本")
    var rawText: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .result(dialog: "失败：快捷指令没有传过来截图文字。")
        }
        
        let schema = Schema([Transaction.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let recentTransactions = (try? context.fetch(descriptor)) ?? []
        
        var habitDict = [String: String]()
        for tx in recentTransactions {
            if habitDict[tx.merchant] == nil {
                habitDict[tx.merchant] = tx.category
            }
            if habitDict.count >= 20 { break }
        }
        let habitString = habitDict.map { "\($0.key) -> \($0.value)" }.joined(separator: ", ")
        
        let (parsedData, errorMessage) = await callRealAIAPI(text: rawText, habits: habitString)
        
        // 🌟 这里的校验逻辑：如果解析结果为空或者金额依然是 0，直接报错提示
        guard let parsedData = parsedData, parsedData.amount > 0 else {
            return .result(dialog: "❌ 记账失败：AI 未能识别到有效金额（识别结果为 0.00）。请确保截图清晰且包含支付数值。")
        }
        
        let newTx = Transaction(
            amount: parsedData.amount,
            merchant: parsedData.merchant,
            paymentMethod: parsedData.paymentMethod,
            category: parsedData.category,
            isIncome: parsedData.isIncome,
            date: parsedData.transactionDate ?? Date()
        )
        context.insert(newTx)
        try context.save()
        
        let typeStr = parsedData.isIncome ? "收入" : "支出"
        return .result(dialog: "✅ 记账成功！(\(parsedData.merchant) \(typeStr) \(parsedData.amount)元)")
    }
    
    private func callRealAIAPI(text: String, habits: String) async -> (ParsedResult?, String) {
        let apiKey = "sk-78f33cba6d8844d4861d6d63d4e756c5"
        
        guard let url = URL(string: "https://api.deepseek.com/chat/completions") else {
            return (nil, "请求URL错误")
        }
        
        // --- 🌟 针对金额识别的终极 Prompt 🌟 ---
        var systemPrompt = """
        # Role
        你是一个财务账单提取专家，严禁提取到 0.00 作为金额。
        
        # Constraints
        1. **金额绝对性**：真实的账单金额绝对不可能是 0。
        2. **提取逻辑**：
           - 忽略所有 0.00 的数值。
           - 寻找文本中最大的数字，或者紧跟在“付款”、“合计”、“实付”、“金额”、“-”、“¥”之后的数字。
           - 如果有多个数字，优先选择带有小数点的、位于页面中心或顶部的数值。
        3. **商户深度识别**：忽略“美团/支付宝/微信”等平台名，提取具体的店铺名称。
        """
        
        if !habits.isEmpty {
            systemPrompt += "\n# User Habits\n优先参考习惯分类：[\(habits)]"
        }
        
        systemPrompt += "\n# Output\n只返回 JSON：{amount: Double, merchant: String, category: String, paymentMethod: String, isIncome: Bool, dateString: 'yyyy-MM-dd HH:mm:ss'}"
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                return (nil, "服务器错误: \(httpResponse.statusCode)")
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                guard let start = content.firstIndex(of: "{"),
                      let end = content.lastIndex(of: "}") else {
                    return (nil, "格式错误")
                }
                
                let jsonString = String(content[start...end])
                if let result = parseJSONToResult(jsonString) {
                    return (result, "")
                }
            }
            return (nil, "无法解析数据")
        } catch {
            return (nil, "请求异常：\(error.localizedDescription)")
        }
    }
    
    private func parseJSONToResult(_ jsonString: String) -> ParsedResult? {
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        // 🌟 强效金额获取：不仅解析 Double，也尝试从 String 转换
        var amount = 0.0
        if let val = dict["amount"] as? Double {
            amount = val
        } else if let str = dict["amount"] as? String, let val = Double(str) {
            amount = val
        }
        
        // 🌟 最终检查：如果 AI 还是倔强地返回了 0，此函数直接返回 nil 触发报错
        if amount <= 0 { return nil }
        
        let merchant = dict["merchant"] as? String ?? "未知商户"
        let category = dict["category"] as? String ?? "📦 其他"
        let method = dict["paymentMethod"] as? String ?? "其他"
        let isIncome = dict["isIncome"] as? Bool ?? false
        
        var txDate: Date? = nil
        if let dateStr = dict["dateString"] as? String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            txDate = formatter.date(from: dateStr)
        }
        
        return ParsedResult(amount: amount, merchant: merchant, category: category, paymentMethod: method, isIncome: isIncome, transactionDate: txDate)
    }
    
    struct ParsedResult {
        var amount: Double
        var merchant: String
        var category: String
        var paymentMethod: String
        var isIncome: Bool
        var transactionDate: Date?
    }
}
