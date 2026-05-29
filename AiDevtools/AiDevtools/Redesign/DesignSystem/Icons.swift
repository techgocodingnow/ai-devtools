import SwiftUI

/// Design icon set (icons.jsx) mapped to the closest SF Symbol — the native idiom on macOS.
enum Icons {
    static let search = "magnifyingglass"
    static let chev = "chevron.right"
    static let chevDown = "chevron.down"
    static let chevUp = "chevron.up"
    static let swap = "arrow.left.arrow.right"
    static let plus = "plus"
    static let minus = "minus"
    static let x = "xmark"
    static let check = "checkmark"
    static let more = "ellipsis"
    static let cog = "gearshape"
    static let box = "shippingbox"
    static let zap = "bolt.fill"
    static let plug = "powerplug"
    static let folder = "folder"
    static let globe = "globe"
    static let shop = "bag"
    static let layers = "square.stack.3d.up"
    static let user = "person"
    static let star = "star"
    static let starFill = "star.fill"
    static let download = "arrow.down.to.line"
    static let upload = "arrow.up.to.line"
    static let trash = "trash"
    static let refresh = "arrow.clockwise"
    static let link = "link"
    static let shield = "shield"
    static let shieldOk = "checkmark.shield"
    static let alert = "exclamationmark.triangle.fill"
    static let info = "info.circle"
    static let power = "power"
    static let filter = "line.3.horizontal.decrease"
    static let sort = "arrow.up.arrow.down"
    static let grip = "line.3.horizontal"
    static let external = "arrow.up.right.square"
    static let copy = "doc.on.doc"
    static let list = "list.bullet"
    static let grid = "square.grid.2x2"
    static let edit = "pencil"
    static let scan = "viewfinder"
    static let terminal = "terminal"
    static let history = "clock.arrow.circlepath"
    static let workspace = "cube.transparent"
    static let database = "cylinder.split.1x2"
    static let branch = "arrow.triangle.branch"
    static let cube = "cube"
}

/// A sized SF Symbol that inherits its color from the surrounding `foregroundStyle`.
struct Sym: View {
    let name: String
    var size: CGFloat = 14
    var weight: Font.Weight = .medium
    init(_ name: String, size: CGFloat = 14, weight: Font.Weight = .medium) {
        self.name = name
        self.size = size
        self.weight = weight
    }
    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: weight))
    }
}
