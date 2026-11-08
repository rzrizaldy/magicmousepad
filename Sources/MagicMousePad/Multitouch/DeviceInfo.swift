import Foundation
import IOKit

/// What we know about one multitouch device (Magic Mouse, trackpad, …).
struct DeviceInfo: Identifiable, Equatable {
    let index: Int32
    let familyID: Int
    let productID: Int
    let builtIn: Bool
    let transport: String
    /// Physical surface size in millimetres (0 when unknown).
    let widthMM: Double
    let heightMM: Double

    var id: Int32 { index }

    private static let mouseProductIDs: Set<Int> = [0x030D, 0x0269, 0x0323]
    private static let mouseFamilyIDs: Set<Int> = [112, 113]

    /// True for every Magic Mouse generation, including the USB-C model.
    var isMagicMouse: Bool {
        if Self.mouseProductIDs.contains(productID) || Self.mouseFamilyIDs.contains(familyID) { return true }
        // Fallback: a mouse's touch surface is taller than it is wide; trackpads are the opposite.
        return !builtIn && widthMM > 0 && heightMM > widthMM
    }

    var name: String {
        switch productID {
        case 0x030D: return "Magic Mouse"
        case 0x0269: return "Magic Mouse 2"
        case 0x0323: return "Magic Mouse (USB‑C)"
        case 0x0265: return "Magic Trackpad 2"
        case 0x0324: return "Magic Trackpad (USB‑C)"
        default:
            if builtIn { return "Built-in Trackpad" }
            return isMagicMouse ? "Magic Mouse" : "Multitouch Device"
        }
    }

    /// Sample device for README screenshots (`--snapshot`).
    static let demo = DeviceInfo(index: 0, familyID: 112, productID: 0x0323, builtIn: false,
                                 transport: "Bluetooth", widthMM: 51.5, heightMM: 90.6)

    private init(index: Int32, familyID: Int, productID: Int, builtIn: Bool, transport: String, widthMM: Double, heightMM: Double) {
        self.index = index
        self.familyID = familyID
        self.productID = productID
        self.builtIn = builtIn
        self.transport = transport
        self.widthMM = widthMM
        self.heightMM = heightMM
    }

    init(index: Int32, service: io_service_t) {
        func prop(_ key: String) -> Any? {
            IORegistryEntrySearchCFProperty(
                service, kIOServicePlane, key as CFString, kCFAllocatorDefault,
                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
            )
        }
        self.index = index
        self.familyID = (prop("Family ID") as? NSNumber)?.intValue ?? 0
        self.productID = (prop("ProductID") as? NSNumber)?.intValue ?? 0
        self.builtIn = (prop("MT Built-In") as? Bool) ?? false
        self.transport = (prop("Transport") as? String) ?? ""
        // Surface dimensions are reported in hundredths of a millimetre.
        self.widthMM = ((prop("Sensor Surface Width") as? NSNumber)?.doubleValue ?? 0) / 100
        self.heightMM = ((prop("Sensor Surface Height") as? NSNumber)?.doubleValue ?? 0) / 100
    }
}
