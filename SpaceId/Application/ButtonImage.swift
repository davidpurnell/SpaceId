import Cocoa
import Foundation

class ButtonImage {
    
    private let size = CGSize(width: 25, height: 14)
    private let defaults = UserDefaults.standard
    typealias F = (ButtonImage) -> (SpaceInfo) -> NSImage
    
    func createImage(spaceInfo: SpaceInfo) -> NSImage {
        guard let icon = Preference.Icon(rawValue: defaults.integer(forKey: Preference.icon)),
              let color = Preference.Color(rawValue: defaults.integer(forKey: Preference.color))
        else { return oneIcon(spaceInfo: spaceInfo, color: Preference.Color.blackOnWhite) }
        let underline = defaults.bool(forKey: Preference.App.underlineActiveMonitor.rawValue)
        let numbered = defaults.bool(forKey: Preference.App.numberedSpaces.rawValue)
        switch icon {
        case Preference.Icon.one:
            return oneIcon(spaceInfo: spaceInfo, color: color)
        case Preference.Icon.perMonitor:
            return perMonitor(spaceInfo: spaceInfo, color: color, underlineActiveMonitor: underline)
        case Preference.Icon.perSpace:
            return perSpace(spaceInfo: spaceInfo, color: color, underlineActiveMonitor: underline, numberedSpaces: numbered)
        }
    }

    private func colorF(color: Preference.Color) -> (String, CGFloat, Bool, Bool) -> NSImage {
        switch color {
        case Preference.Color.blackOnWhite:
            return blackOnWhite
        case Preference.Color.whiteOnBlack:
            return whiteOnBlack
        }
    }

    private func textAttributes(color: NSColor, underline: Bool) -> [NSAttributedString.Key: Any] {
        let font = NSFont.boldSystemFont(ofSize: 11)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center
        
        return [ .font: font,
                 .foregroundColor: color,
                 .paragraphStyle: paragraphStyle,
                 .underlineStyle: underline
               ]
    }
    
    private func blackOnWhite(text: String, alpha: CGFloat = 1, underline: Bool, numbered: Bool) -> NSImage {
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        /* making a slightly smaller rect for the sroked path since I can't figure out how to do an inset stroke */
        let pathrect = NSRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
        let image = NSImage(size: size)
        let color = NSColor.init(white: 0, alpha: alpha)
        let path = NSBezierPath(roundedRect: pathrect, xRadius: 3, yRadius: 3)
        image.lockFocus()
        color.set()
        path.lineWidth = 1.5
        var text2:String = ""
        if (text != "99") {
            path.stroke()
            if (numbered) { text2 = text }
        }
        text2.drawVerticallyCentered(in:rect, withAttributes: textAttributes(color: color, underline: underline))
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    private func whiteOnBlack(text: String, alpha: CGFloat, underline: Bool, numbered: Bool) -> NSImage {
        let rect = NSRect(x: 0, y: 0, width: size.width, height: size.height)
        let image = NSImage(size: size)
        let image1 = NSImage(size: size)
        let image2 = NSImage(size: size)
        let color = NSColor.init(white: 1, alpha: alpha)
        
        if (text != "99") {
            image1.lockFocus()
            color.set()
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            path.fill()
            image1.unlockFocus()
        }
        var text2:String = ""
        if (numbered) { text2 = text }
        image2.lockFocus()
        text2.drawVerticallyCentered(in: rect, withAttributes: textAttributes(color: NSColor.black, underline: underline))
        image2.unlockFocus()

        image.lockFocus()
        image1.draw(in: rect, from: NSZeroRect, operation: NSCompositingOperation.sourceOut, fraction: 1.0)
        image2.draw(in: rect, from: NSZeroRect, operation: NSCompositingOperation.destinationOut, fraction: 1.0)
        image.unlockFocus()
        
        image.isTemplate = true
        return image
    }
    
    private func combinePerMonitor(icons: [NSImage], count: Int) -> NSImage {
        let fatX = size.width + 5
        let width = fatX * CGFloat(count)
        let image = NSImage(size: CGSize(width: width, height: size.height))
        image.lockFocus()
        var x: CGFloat = 0
        for i in icons {
            i.draw(at: NSPoint(x: x, y: 0), from: NSZeroRect, operation: NSCompositingOperation.color, fraction: 1.0)
            x += fatX
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    private func combinePerSpace(icons: [NSImage], count: Int, monitorSpaces: [Int]) -> NSImage {
        let fakeSpaceCount = monitorSpaces.count
        let realSpaceCount = count - fakeSpaceCount
        let fatX = size.width + 5
        let skinnyX = size.width/2
        let width = fatX * CGFloat(realSpaceCount) + skinnyX * CGFloat(fakeSpaceCount - 1)
        //let width = size.width * CGFloat(count) + CGFloat(5 * (count - 1))
        let image = NSImage(size: CGSize(width: width, height: size.height))
        image.lockFocus()
        var x: CGFloat = 0
        var iconCount = 0
        var monitorCount = 0
        for i in icons {
            i.draw(at: NSPoint(x: x, y: 0), from: NSZeroRect, operation: NSCompositingOperation.color, fraction: 1.0)

            if (monitorSpaces[monitorCount] == iconCount) {
                monitorCount += 1
                x += skinnyX
            } else {
                x += fatX
            }
            iconCount += 1
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func oneIcon(spaceInfo: SpaceInfo, color: Preference.Color) -> NSImage {
        return colorF(color: color)(getTextForSpace(space: spaceInfo.keyboardFocusSpace), 1, false, true)
    }
    
    private func perMonitor(spaceInfo:SpaceInfo, color: Preference.Color, underlineActiveMonitor: Bool) -> NSImage {
        let spaces = spaceInfo.activeSpaces.sorted{ $0.order < $1.order }
        let icons = spaces.map {
            colorF(color: color)(getTextForSpace(space: $0), 1, underlineActiveMonitor ? $0.uuid == spaceInfo.keyboardFocusSpace?.uuid : false, true)
        }
        return combinePerMonitor(icons: icons, count: spaces.count)
    }
    
    private func perSpace(spaceInfo: SpaceInfo, color: Preference.Color, underlineActiveMonitor: Bool, numberedSpaces: Bool) -> NSImage {
        let icons = spaceInfo.allSpaces.map {
            colorF(color: color)(getTextForSpace(space: $0), getAlpha(space: $0), underlineActiveMonitor ? $0.uuid == spaceInfo.keyboardFocusSpace?.uuid : false, numberedSpaces)
        }
        return combinePerSpace(icons: icons, count: spaceInfo.allSpaces.count, monitorSpaces: spaceInfo.monitorSpaces)
    }
    
    private func getAlpha(space: Space) -> CGFloat {
        return space.isActive ? 1 : 0.3
    }
    
    private func getTextForSpace(space: Space?) -> String {
        return space.map { $0.number.map { String($0) } ?? "F" } ?? "0"
    }
    
}

extension NSString {
    func drawVerticallyCentered(
        in rect: CGRect,
        withAttributes attributes: [NSAttributedString.Key : Any]? = nil)
    {
        let size = self.size(withAttributes: attributes)
        let centeredRect = CGRect(
            x: rect.origin.x,
            y: rect.origin.y + (rect.size.height-size.height)/2.0,
            width: rect.size.width,
            height: size.height
        )
        self.draw(in: centeredRect, withAttributes: attributes)
    }
}
