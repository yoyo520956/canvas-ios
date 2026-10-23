import UIKit

/// 全局设计令牌：深色高对比配色 + 字号阶梯
/// 对比度基准：正文 #F7F9FC on #0B0D12 ≈ 18:1，次要文字 ≈ 9:1（WCAG AAA/AA）
enum CanvasTheme {
    // MARK: 背景
    static let canvasBG = UIColor(red: 0.043, green: 0.051, blue: 0.070, alpha: 1)
    static let gridDot = UIColor(red: 0.24, green: 0.30, blue: 0.40, alpha: 0.85)
    static let gridLine = UIColor(red: 0.16, green: 0.20, blue: 0.27, alpha: 0.55)

    // MARK: 卡片 / 控件底
    static let cardBG = UIColor(red: 0.098, green: 0.114, blue: 0.149, alpha: 1)
    static let cardBorder = UIColor(red: 0.30, green: 0.35, blue: 0.44, alpha: 1)
    static let headerBG = UIColor(red: 0.125, green: 0.145, blue: 0.188, alpha: 1)
    static let fieldBG = UIColor(red: 0.145, green: 0.168, blue: 0.216, alpha: 1)
    static let chipBG = UIColor(red: 0.18, green: 0.21, blue: 0.27, alpha: 1)

    // MARK: 文字（关键：全部比旧版亮一大截）
    static let textPrimary = UIColor(red: 0.969, green: 0.976, blue: 0.988, alpha: 1)
    static let textSecondary = UIColor(red: 0.76, green: 0.80, blue: 0.86, alpha: 1)
    static let textTertiary = UIColor(red: 0.60, green: 0.65, blue: 0.72, alpha: 1)

    // MARK: 强调色
    static let accent = UIColor(red: 0.16, green: 0.86, blue: 1.0, alpha: 1)
    static let accentDeep = UIColor(red: 0.02, green: 0.42, blue: 0.55, alpha: 1)
    static let onAccent = UIColor(red: 0.02, green: 0.10, blue: 0.14, alpha: 1)
    static let success = UIColor(red: 0.33, green: 0.91, blue: 0.58, alpha: 1)
    static let danger = UIColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1)
    static let warning = UIColor(red: 1.0, green: 0.78, blue: 0.30, alpha: 1)
    static let violet = UIColor(red: 0.72, green: 0.62, blue: 1.0, alpha: 1)

    // MARK: 字号阶梯（正文最小 15pt，按钮 16pt，禁用 11pt 以下的正文）
    static let fBadge: CGFloat = 12
    static let fStatus: CGFloat = 13
    static let fBody: CGFloat = 15
    static let fTitle: CGFloat = 16
    static let fButton: CGFloat = 16

    static var badge: UIFont { .systemFont(ofSize: fBadge, weight: .bold) }
    static var status: UIFont { .systemFont(ofSize: fStatus, weight: .semibold) }
    static var body: UIFont { .systemFont(ofSize: fBody, weight: .regular) }
    static var bodyMedium: UIFont { .systemFont(ofSize: fBody, weight: .medium) }
    static var title: UIFont { .systemFont(ofSize: fTitle, weight: .bold) }
    static var button: UIFont { .systemFont(ofSize: fButton, weight: .bold) }

    // MARK: 圆角
    static let rCard: CGFloat = 18
    static let rField: CGFloat = 12
    static let rChip: CGFloat = 8

    /// 带柔和外发光的阴影（选中态/主卡片）
    static func glow(_ view: UIView, _ color: UIColor, radius: CGFloat = 14, opacity: Float = 0.5) {
        view.layer.shadowColor = color.cgColor
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = radius
        view.layer.shadowOffset = .zero
    }
}
