#if DEBUG
import SwiftUI
import UIKit

public struct CellPreview<Cell: UIView>: View {
    private let cell: Cell
    private let width: CGFloat
    private let height: CGFloat?

    public init(_ cell: Cell, width: CGFloat = 375, height: CGFloat? = nil) {
        self.cell = cell
        self.width = width
        self.height = height
    }

    public var body: some View {
        CellRepresentable(cell: cell)
            .frame(width: width, height: height)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}

private struct CellRepresentable<Cell: UIView>: UIViewRepresentable {
    let cell: Cell

    func makeUIView(context: Context) -> Cell { cell }

    func updateUIView(_ uiView: Cell, context: Context) {}
}
#endif
