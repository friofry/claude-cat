import ClaudeCatCore
import CoreGraphics

/// Every user-facing string, so the core stays free of presentation.
enum Strings {
    static func title(_ record: SessionRecord) -> String {
        record.title ?? "Claude"
    }

    /// `pending` is what the user already sent to the session from ClaudeCat.
    static func subtitle(_ card: BoardCard, pending: InboxItem? = nil) -> String {
        let record = card.record
        switch pending {
        case .stop?: return "Остановится на следующем шаге…"
        case .message?: return "Сообщение дойдёт на следующем шаге…"
        case nil: break
        }
        switch card.kind {
        case .waiting: return record.waitReason.map(wait) ?? "Claude ждёт тебя"
        case .done: return nonEmpty(record.reply) ?? "Готово"
        case .working: return record.activity.map(activity) ?? "Работает…"
        }
    }

    static func activity(_ activity: Activity) -> String {
        switch activity {
        case .thinking: return "Думает…"
        case .command(let description): return description ?? "Выполняет команду"
        case .reading(let file): return "Читает \(file)"
        case .editing(let file): return "Правит \(file)"
        case .searchingCode: return "Ищет в коде"
        case .searchingWeb: return "Ищет в сети"
        case .agent(let description): return "Агент: \(description ?? "работает")"
        case .planning: return "Обновляет план"
        case .skill(let name): return "Скилл \(name)"
        case .tool(let name): return "Инструмент \(name)"
        }
    }

    static func wait(_ reason: WaitReason) -> String {
        switch reason {
        case .question(let text): return nonEmpty(text) ?? "Claude задаёт вопрос"
        case .permission(let tool): return "Нужно разрешение: \(tool)"
        case .planApproval: return "План готов, нужно одобрение"
        case .notice(let text): return nonEmpty(text) ?? "Claude ждёт тебя"
        }
    }

    static func state(_ state: SessionState) -> String {
        switch state {
        case .idle: return "простаивает"
        case .working: return "работает"
        case .waiting: return "ждёт тебя"
        case .done: return "готово"
        }
    }

    static func skin(_ id: String) -> String {
        ["cat": "Котик", "clawd": "Clawd", "slime": "Слайм"][id] ?? id
    }

    static let sizes: [(name: String, pixel: CGFloat)] = [("Маленький", 3), ("Средний", 3.5), ("Большой", 5)]

    enum Composer {
        static let newChat = "Новый чат: опиши задачу"
        static func message(_ title: String) -> String { "Сообщение для «\(title)»" }
        static func reply(_ title: String) -> String { "Ответить в «\(title)»" }
        static let sent = "Отправлено"
        static let copied = "Текст в буфере обмена — вставь его в сессию"
    }

    enum Menu {
        static let noSessions = "Нет активных сессий"
        static let pet = "Питомец"
        static let size = "Размер"
        static let hideCards = "Скрыть все карточки"
        static let forgetSessions = "Забыть все сессии"
        static let backToDock = "Вернуть к Dock"
        static let quit = "Выйти"
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }
}
