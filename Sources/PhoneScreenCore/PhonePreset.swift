import Foundation

/// A phone panel's native pixel size.
///
/// Apple lists iPhone resolution as the long side first ("2532-by-1170").
/// Portrait width is the shorter side. Landscape swaps the two.
public struct PhonePreset: Equatable, Identifiable, Codable {
    public var id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var ppi: Int
    /// Human-readable source, shown in the menu and the README.
    public var citation: String

    public init(id: String, name: String, width: Int, height: Int, ppi: Int, citation: String) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.ppi = ppi
        self.citation = citation
    }

    public var swapped: PhonePreset {
        PhonePreset(
            id: id + ".swapped",
            name: name,
            width: height,
            height: width,
            ppi: ppi,
            citation: citation
        )
    }
}

public enum PhonePresets {
    /// Portrait 1170×2532. Apple lists this panel as 2532-by-1170 at 460 ppi.
    /// https://www.apple.com/iphone-17e/specs/
    public static let iPhone17ePortrait = PhonePreset(
        id: "iphone-17e-portrait",
        name: "iPhone 17e / 16e 竖屏",
        width: 1170,
        height: 2532,
        ppi: 460,
        citation: "Apple iPhone 17e 技术规格：2532-by-1170-pixel resolution at 460 ppi"
    )

    /// 1170×2000: leaves room above and below when UU 远程 letterboxes it,
    /// clearing the notch at the top and UU's toolbar at the bottom.
    public static let iPhone17eUUSafe = PhonePreset(
        id: "iphone-17e-uu-safe",
        name: "iPhone 17e 避开刘海（UU）",
        width: 1170,
        height: 2000,
        ppi: 460,
        citation: "基于 iPhone 17e 2532×1170，上下让出刘海和 UU 工具栏的位置"
    )

    /// https://www.oneplus.com/cn/ace-6t/specs — FHD+ 2800×1272 像素，450 PPI。
    public static let onePlusAce6TPortrait = PhonePreset(
        id: "oneplus-ace-6t-portrait",
        name: "一加 Ace 6T",
        width: 1272,
        height: 2800,
        ppi: 450,
        citation: "一加官网 Ace 6T 参数：FHD+ 2800×1272 像素，450 PPI"
    )

    public static let iPhone17eLandscape = PhonePreset(
        id: "iphone-17e-landscape",
        name: "iPhone 17e / 16e 横屏",
        width: 2532,
        height: 1170,
        ppi: 460,
        citation: iPhone17ePortrait.citation
    )

    /// https://www.apple.com/iphone-17/specs/ and https://www.apple.com/iphone-17-pro/specs/
    /// Both list 2622-by-1206-pixel resolution at 460 ppi.
    public static let iPhone17And17ProPortrait = PhonePreset(
        id: "iphone-17-pro-portrait",
        name: "iPhone 17 / 17 Pro / 16 Pro",
        width: 1206,
        height: 2622,
        ppi: 460,
        citation: "Apple：iPhone 17 与 iPhone 17 Pro 均为 2622-by-1206-pixel resolution at 460 ppi"
    )

    /// https://www.apple.com/iphone-17-pro/specs/ — 2868-by-1320-pixel resolution at 460 ppi.
    public static let iPhone17ProMaxPortrait = PhonePreset(
        id: "iphone-17-pro-max-portrait",
        name: "iPhone 17 Pro Max / 16 Pro Max",
        width: 1320,
        height: 2868,
        ppi: 460,
        citation: "Apple iPhone 17 Pro Max：2868-by-1320-pixel resolution at 460 ppi"
    )

    /// https://www.apple.com/iphone-air/specs/ — 2736-by-1260-pixel resolution at 460 ppi.
    public static let iPhoneAirPortrait = PhonePreset(
        id: "iphone-air-portrait",
        name: "iPhone Air",
        width: 1260,
        height: 2736,
        ppi: 460,
        citation: "Apple iPhone Air：2736-by-1260-pixel resolution at 460 ppi"
    )

    /// Samsung lists Galaxy S25 as 2340 x 1080 (FHD+), 6.2-inch full rectangle.
    /// ppi is derived: hypot(2340, 1080) / 6.2 ≈ 416. Samsung's page does not
    /// publish a separate ppi figure for this model.
    public static let galaxyS25Portrait = PhonePreset(
        id: "galaxy-s25-portrait",
        name: "Galaxy S25",
        width: 1080,
        height: 2340,
        ppi: 416,
        citation: "Samsung Galaxy S25：Resolution (Main Display) 2340 x 1080 (FHD+)。ppi 由 6.2 英寸对角线推算约为 416"
    )

    /// Samsung Newsroom, Galaxy Z Fold7 cover: 2520 x 1080 at 422 ppi.
    public static let galaxyZFold7Cover = PhonePreset(
        id: "galaxy-z-fold7-cover",
        name: "Z Fold7 外屏",
        width: 1080,
        height: 2520,
        ppi: 422,
        citation: "Samsung Galaxy Z Fold7 外屏：2520 x 1080，422 ppi"
    )

    /// Samsung Newsroom, Galaxy Z Fold7 main: 2184 x 1968 at 368 ppi.
    /// Unfolded chassis is taller than it is wide, so 1968 is the portrait width.
    public static let galaxyZFold7Inner = PhonePreset(
        id: "galaxy-z-fold7-inner",
        name: "Z Fold7 内屏",
        width: 1968,
        height: 2184,
        ppi: 368,
        citation: "Samsung Galaxy Z Fold7 内屏：2184 x 1968，368 ppi"
    )


    // MARK: - 常见手机（数据均来自官方参数页）

    /// https://support.apple.com/en-us/121029 (iPhone 16) and
    /// https://support.apple.com/en-us/111831 (iPhone 15): 2556-by-1179 at 460 ppi.
    public static let iPhone16And15Portrait = PhonePreset(
        id: "iphone-16-portrait",
        name: "iPhone 16 / 15",
        width: 1179, height: 2556, ppi: 460,
        citation: "Apple：iPhone 16 与 iPhone 15 均为 2556-by-1179-pixel resolution at 460 ppi"
    )

    /// https://support.apple.com/en-us/121030 — iPhone 16 Plus: 2796-by-1290 at 460 ppi.
    public static let iPhone16PlusPortrait = PhonePreset(
        id: "iphone-16-plus-portrait",
        name: "iPhone 16 Plus",
        width: 1290, height: 2796, ppi: 460,
        citation: "Apple iPhone 16 Plus：2796-by-1290-pixel resolution at 460 ppi"
    )

    /// https://consumer.huawei.com/cn/phones/mate70/specs/ — 6.7 英寸 FHD+ 2688 × 1216。
    /// 官网未写 PPI，按对角线推算约 440。
    public static let huaweiMate70Portrait = PhonePreset(
        id: "huawei-mate-70-portrait",
        name: "华为 Mate 70",
        width: 1216, height: 2688, ppi: 440,
        citation: "华为官网 Mate 70 参数：6.7 英寸 FHD+ 2688 × 1216 像素（PPI 由对角线推算约 440）"
    )

    /// https://consumer.huawei.com/cn/phones/pura80/specs/ — FHD+ 2760 × 1256，460 ppi。
    public static let huaweiPura80Portrait = PhonePreset(
        id: "huawei-pura-80-portrait",
        name: "华为 Pura 80 / OPPO Find X8",
        width: 1256, height: 2760, ppi: 460,
        citation: "华为官网 Pura 80：FHD+ 2760 × 1256 像素，460 ppi；OPPO 官网 Find X8：2760×1256 像素，460 PPI"
    )

    /// https://www.mi.com/global/product/xiaomi-15/specs/ — 2670 x 1200, 460 ppi.
    public static let xiaomi15Portrait = PhonePreset(
        id: "xiaomi-15-portrait",
        name: "小米 15",
        width: 1200, height: 2670, ppi: 460,
        citation: "小米官网 Xiaomi 15 参数：Resolution 2670 x 1200, 460 ppi"
    )

    /// https://www.vivo.com.cn/vivo/param/x200 — 6.67 英寸 2800 × 1260。
    /// 官网未写 PPI，按对角线推算约 460。
    public static let vivoX200Portrait = PhonePreset(
        id: "vivo-x200-portrait",
        name: "vivo X200",
        width: 1260, height: 2800, ppi: 460,
        citation: "vivo 官网 X200 参数：6.67 英寸 2800 × 1260（PPI 由对角线推算约 460）"
    )

    public static let all: [PhonePreset] = [
        iPhone17ePortrait,
        iPhone17eUUSafe,
        iPhone17eLandscape,
        onePlusAce6TPortrait,
        iPhone17And17ProPortrait,
        iPhone17ProMaxPortrait,
        iPhoneAirPortrait,
        iPhone16And15Portrait,
        iPhone16PlusPortrait,
        huaweiMate70Portrait,
        huaweiPura80Portrait,
        xiaomi15Portrait,
        vivoX200Portrait,
        galaxyS25Portrait,
        galaxyZFold7Cover,
        galaxyZFold7Inner,
    ]

    public static func matching(width: Int, height: Int) -> PhonePreset? {
        all.first { $0.width == width && $0.height == height }
    }
}
