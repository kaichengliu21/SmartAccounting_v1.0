import Foundation

struct CategoryManager {
    // 根据商户名称自动推断分类
    static func guessCategory(for merchant: String) -> String {
        let lowerMerchant = merchant.lowercased()
        
        if lowerMerchant.contains("瑞幸") || lowerMerchant.contains("星巴克") || lowerMerchant.contains("咖啡") || lowerMerchant.contains("餐饮") || lowerMerchant.contains("麦当劳") || lowerMerchant.contains("外卖") {
            return "🍔 餐饮"
        } else if lowerMerchant.contains("滴滴") || lowerMerchant.contains("地铁") || lowerMerchant.contains("公交") || lowerMerchant.contains("打车") || lowerMerchant.contains("12306") {
            return "🚗 交通"
        } else if lowerMerchant.contains("超市") || lowerMerchant.contains("便利店") || lowerMerchant.contains("全家") || lowerMerchant.contains("淘宝") {
            return "🛒 购物"
        } else if lowerMerchant.contains("工资") || lowerMerchant.contains("奖金") {
            return "💰 收入"
        } else {
            return "📦 其他" // 匹配不到关键词时的默认分类
        }
    }
}
