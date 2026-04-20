import SwiftUI
import SwiftData
import Charts

enum TimeRange {
    case month
    case year
    case allTime
}

struct StatsView: View {
    @Query(sort: \Transaction.date, order: .forward) private var allTransactions: [Transaction]
    
    @State private var timeRange: TimeRange = .month
    @State private var showIncome: Bool = false
    @State private var selectedDate: Date = Date()
    
    var filteredTransactions: [Transaction] {
        let calendar = Calendar.current
        switch timeRange {
        case .month:
            return allTransactions.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .month) }
        case .year:
            return allTransactions.filter { calendar.isDate($0.date, equalTo: selectedDate, toGranularity: .year) }
        case .allTime:
            return allTransactions
        }
    }
    
    var currentIncome: Double {
        filteredTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var currentExpense: Double {
        filteredTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }
    
    var currentBalance: Double {
        currentIncome - currentExpense
    }
    
    var categoryRanking: [(category: String, total: Double, percentage: Double)] {
        let targetTransactions = filteredTransactions.filter { $0.isIncome == showIncome }
        let totalAmount = targetTransactions.reduce(0) { $0 + $1.amount }
        
        guard totalAmount > 0 else { return [] }
        
        let grouped = Dictionary(grouping: targetTransactions, by: { $0.category })
        return grouped.map { key, value in
            let total = value.reduce(0) { $0 + $1.amount }
            return (category: key, total: total, percentage: total / totalAmount)
        }.sorted { $0.total > $1.total }
    }
    
    var overviewTitle: String {
        switch timeRange {
        case .month: return "本月概览"
        case .year: return "本年概览"
        case .allTime: return "历史总览"
        }
    }
    
    var emptyStateText: String {
        switch timeRange {
        case .month: return "本月"
        case .year: return "本年"
        case .allTime: return "历史"
        }
    }
    
    var incomeTitle: String {
        switch timeRange {
        case .month: return "本月收入"
        case .year: return "本年收入"
        case .allTime: return "总收入"
        }
    }
    
    var expenseTitle: String {
        switch timeRange {
        case .month: return "本月支出"
        case .year: return "本年支出"
        case .allTime: return "总支出"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 📅 顶部时间选择与数据看板
                    VStack(spacing: 16) {
                        HStack {
                            Text(overviewTitle)
                                .font(.title2)
                                .bold()
                            
                            Spacer()
                            
                            Picker("时间范围", selection: $timeRange) {
                                Text("看本月").tag(TimeRange.month)
                                Text("看本年").tag(TimeRange.year)
                                Text("看全部").tag(TimeRange.allTime)
                            }
                            .pickerStyle(.menu)
                            .tint(.gray)
                        }
                        
                        HStack(spacing: 12) {
                            SummaryCard(title: incomeTitle, amount: currentIncome, color: .green)
                            SummaryCard(title: expenseTitle, amount: currentExpense, color: .red)
                            SummaryCard(title: "结余", amount: currentBalance, color: currentBalance >= 0 ? .blue : .red)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    // 🎛️ 收支维度切换器
                    Picker("查看类型", selection: $showIncome) {
                        Text("看支出").tag(false)
                        Text("看收入").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 📈 动态趋势与排行榜
                    if categoryRanking.isEmpty {
                        VStack {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                                .padding()
                            
                            // 极简拼接，防止编译器报错
                            Text(emptyStateText + "暂无" + (showIncome ? "收入" : "支出") + "记录")
                                .foregroundColor(.gray)
                        }
                        .frame(height: 300)
                    } else {
                        // 📊 饼状图
                        Chart(categoryRanking, id: \.category) { item in
                            SectorMark(
                                angle: .value("金额", item.total),
                                innerRadius: .ratio(0.55),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("分类", item.category))
                        }
                        .chartLegend(.hidden)
                        .frame(height: 220)
                        .padding(.horizontal)
                        
                        // 📋 详细分类排行榜列表
                        VStack(alignment: .leading, spacing: 16) {
                            Text(showIncome ? "收入排行榜" : "支出排行榜")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(categoryRanking, id: \.category) { item in
                                HStack {
                                    Text(item.category)
                                        .font(.subheadline)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(String(format: "¥%.2f", item.total))
                                            .font(.subheadline)
                                            .bold()
                                        Text(String(format: "%.1f%%", item.percentage * 100))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.05))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer().frame(height: 40)
                }
                .padding(.top)
            }
            .navigationTitle("收支统计")
        }
    }
}

// 数据卡片组件
struct SummaryCard: View {
    var title: String
    var amount: Double
    var color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            Text(String(format: "¥%.0f", amount))
                .font(.headline)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
