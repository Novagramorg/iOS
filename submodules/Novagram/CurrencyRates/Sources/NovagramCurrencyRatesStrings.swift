import Foundation
import NovagramServicesUI

// The SDK ships no translations: every text of its converter screens comes from here.
enum NovagramCurrencyRatesStrings {
    static func title(langCode: String) -> String {
        switch langCode {
        case "uz": return "Valyuta kurslari"
        case "ru": return "Курсы валют"
        case "zh": return "汇率"
        default:   return "Currency rates"
        }
    }

    static func listTitle(langCode: String) -> String {
        switch langCode {
        case "uz": return "Bir nechta valyuta"
        case "ru": return "Несколько валют"
        case "zh": return "多种货币"
        default:   return "Many currencies"
        }
    }

    static func converter(langCode: String, ratesDate: Date?) -> CurrencyConverterStrings {
        let footer = ratesDate.map { self.footer(date: $0, langCode: langCode) }
        switch langCode {
        case "uz":
            return CurrencyConverterStrings(
                sumName: "O'zbek so'mi", sumSymbol: "so'm", footer: footer,
                swap: "Almashtirish", delete: "O'chirish", copy: "Nusxalash",
                amountLabel: "Miqdor", resultLabel: "Natija", quickAmounts: "Tez miqdor",
                yourAmount: "Sizdagi summa", favorites: "Sevimli valyutalar", tapHint: "Bosing — asosiy bo'ladi",
                addCurrency: "Valyuta qo'shish", makeBase: "Asosiy qilish", remove: "Ro'yxatdan olib tashlash",
                pickerTitle: "Valyuta tanlang", search: "Kod yoki nom", frequent: "Tez-tez",
                allCurrencies: "Barcha valyutalar", noResults: "Topilmadi", close: "Yopish",
                chooseCurrency: "Valyutani tanlash"
            )
        case "ru":
            return CurrencyConverterStrings(
                sumName: "Узбекский сум", sumSymbol: "сум", footer: footer,
                swap: "Поменять местами", delete: "Удалить", copy: "Копировать",
                amountLabel: "Сумма", resultLabel: "Результат", quickAmounts: "Быстрые суммы",
                yourAmount: "Ваша сумма", favorites: "Избранные валюты", tapHint: "Нажмите — станет основной",
                addCurrency: "Добавить валюту", makeBase: "Сделать основной", remove: "Убрать из списка",
                pickerTitle: "Выберите валюту", search: "Код или название", frequent: "Часто",
                allCurrencies: "Все валюты", noResults: "Ничего не найдено", close: "Закрыть",
                chooseCurrency: "Выбрать валюту"
            )
        case "zh":
            return CurrencyConverterStrings(
                sumName: "乌兹别克斯坦苏姆", sumSymbol: "苏姆", footer: footer,
                swap: "交换", delete: "删除", copy: "复制",
                amountLabel: "金额", resultLabel: "结果", quickAmounts: "快捷金额",
                yourAmount: "您的金额", favorites: "收藏的货币", tapHint: "点按设为基准",
                addCurrency: "添加货币", makeBase: "设为基准", remove: "从列表移除",
                pickerTitle: "选择货币", search: "代码或名称", frequent: "常用",
                allCurrencies: "全部货币", noResults: "未找到", close: "关闭",
                chooseCurrency: "选择货币"
            )
        default:
            return CurrencyConverterStrings(
                sumName: "Uzbek sum", sumSymbol: "sum", footer: footer,
                swap: "Swap", delete: "Delete", copy: "Copy",
                amountLabel: "Amount", resultLabel: "Result", quickAmounts: "Quick amounts",
                yourAmount: "Your amount", favorites: "Favorite currencies", tapHint: "Tap to make it the base",
                addCurrency: "Add currency", makeBase: "Make base", remove: "Remove from list",
                pickerTitle: "Choose a currency", search: "Code or name", frequent: "Frequent",
                allCurrencies: "All currencies", noResults: "Nothing found", close: "Close",
                chooseCurrency: "Choose currency"
            )
        }
    }

    // "Markaziy bank kursi, 27-oktabr". The bank sets its rates per Tashkent day.
    private static func footer(date: Date, langCode: String) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Tashkent")
        switch langCode {
        case "uz":
            formatter.locale = Locale(identifier: "uz_Latn_UZ")
            formatter.dateFormat = "d-MMMM"
            return "Markaziy bank kursi, \(formatter.string(from: date))"
        case "ru":
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "d MMMM"
            return "Курс ЦБ Узбекистана, \(formatter.string(from: date))"
        case "zh":
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日"
            return "乌兹别克斯坦央行汇率，\(formatter.string(from: date))"
        default:
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "MMMM d"
            return "Central Bank rate, \(formatter.string(from: date))"
        }
    }
}
