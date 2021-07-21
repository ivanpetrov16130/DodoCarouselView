import SwiftUI


private extension ClosedRange {
  func clampingValue(_ value: Bound) -> Bound { Swift.min(Swift.max(lowerBound, value), upperBound) }
}


private let stackViewCoordinateSpace: String = "LazyHStack"

private struct ChildFramesPreference: PreferenceKey {
  
  static let defaultValue: [Int: CGRect] = [:]
  
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.merge(nextValue(), uniquingKeysWith: { $1 })
  }
  
}

private struct ChildFrameReader: ViewModifier {
  
  var index: Int
  
  func body(content: Content) -> some View {
    content.background(
      GeometryReader { proxy in
        Color.clear.preference(key: ChildFramesPreference.self, value: [self.index: proxy.frame(in: .named(stackViewCoordinateSpace))])
      }
    )
  }
  
}


private struct ProposedSizePreference: PreferenceKey {
  
  static let defaultValue: CGSize? = nil
  
  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = value ?? nextValue()
  }
  
}

private struct ProposedSizeReader: ViewModifier {
  
  func body(content: Content) -> some View {
    content.background(
      GeometryReader { proxy in Color.clear.preference(key: ProposedSizePreference.self, value: proxy.size) }
    )
  }
  
}


public struct DodoCarouselView<Item, Content: View>: View {
  
  private let items: [Item]
  private let proposedInterItemSpacing: CGFloat?
  private let content: (Item) -> Content
  
  @GestureState private var xDragTranslation: CGFloat = 0
  @State private var xContentOffset: CGFloat = 0
  @State private var itemFrames: [Int: CGRect] = [:]
  @State private var contentSize: CGSize?
  
  //Hack: initial incorrect value of 1 is provided to force additional layout cycle in case size proposed by container is incorrect.
  //For example, '.padding()' modifier applied to DodoCarouselView somehow proposes content size of DodoCarouselView instead of the real size of DodoCarouselView's container minus padding edges, which is pretty fucked up
  #warning("Hack!")
  @State private var parentWidth: CGFloat? = 1
  
  private var spacing: CGFloat {
    guard let firstItemFrame = itemFrames[0], let secondItemFrame = itemFrames[1] else { return 0 }
    return secondItemFrame.origin.x - firstItemFrame.width
  }
  private var itemWidth: CGFloat { itemFrames.first?.value.width ?? 0 }
  private var safeXContentOffsetRange: ClosedRange<CGFloat> {
    let contentWidth: CGFloat = contentSize?.width ?? 0
    let xStart = -(contentWidth - itemWidth)
    let xEnd: CGFloat = 0
    return xStart...xEnd
  }
  private let pagingAnimation = Animation.interpolatingSpring(mass: 0.2, stiffness: 20, damping: 3)
  private let scrollingEaseOutAnimation = Animation.timingCurve(0.03, 0.94, 0.59, 0.99).speed(0.25)
  
  
  public init(items: [Item], spacing: CGFloat? = nil, content: @escaping (Item) -> Content) {
    self.items = items
    self.proposedInterItemSpacing = spacing
    self.content = content
  }
  
  public var body: some View {
    
    VStack(alignment: .leading, spacing: 0) {
      
      GeometryReader { proxy in Color.clear.frame(width: proxy.size.width, height: proxy.size.height, alignment: .center) }
        .frame(height: 0)
        .modifier(ProposedSizeReader())
        .onPreferenceChange(ProposedSizePreference.self, perform: { parentWidth = $0?.width })
      
      HStack {
        HStack(spacing: proposedInterItemSpacing) {
          ForEach(items.indices) { index in
            content(items[index])
              .modifier(ChildFrameReader(index: index))
          }
        }
        .coordinateSpace(name: stackViewCoordinateSpace)
        .onPreferenceChange(ChildFramesPreference.self, perform: { itemFrames = $0 })
        .offset(x: xDragTranslation, y: 0)
        .offset(x: xContentOffset, y: 0)
        .simultaneousGesture(
          DragGesture(minimumDistance: 1)
            .updating($xDragTranslation, body: { (value, offset, _) in offset = value.translation.width })
            .onEnded(handleDragGesture(ended:))
        )
        .modifier(ProposedSizeReader())
        .onPreferenceChange(ProposedSizePreference.self, perform: { contentSize = $0 })
      }
      .frame(maxWidth: parentWidth, alignment: .leading)
      
    }
    
  }
  
  private func handleDragGesture(ended value: DragGesture.Value) {
    
    func isDragGestureLong() -> Bool {
      let widthOfTwoItems: CGFloat = itemWidth * 2 + spacing
      return Double(abs(value.predictedEndTranslation.width / widthOfTwoItems )) > 1
    }
    
    func itemFrameWithCenterClosest(to xCoordinate: CGFloat) -> CGRect {
      let correction: CGFloat = itemWidth / 2 + spacing / 2
      return
        (itemFrames
          .mapValues(\.midX)
          .mapValues { $0 - (abs(xCoordinate) + correction) }
          .mapValues(abs)
          .min(by: { (lhs, rhs) -> Bool in lhs.1 < rhs.1 })?
          .key)
        .flatMap { itemFrames[$0] } ?? .zero
    }
    
    func isLastItemInStack(framed itemFrame: CGRect) -> Bool {
      guard let contentSizeWidth = contentSize?.width else { return false }
      return itemFrame == itemFrameWithCenterClosest(to: contentSizeWidth)
    }
    
    func xContentOffsetFocusingItem(closestTo xCoordinate: CGFloat) -> CGFloat {
      let itemToFocusFrame = itemFrameWithCenterClosest(to: xCoordinate)
      let itemToFocusXOrigin = itemToFocusFrame.origin.x
      return  -1 * (isLastItemInStack(framed: itemToFocusFrame) ? itemToFocusXOrigin + spacing : itemToFocusXOrigin)
    }
    
    let xContentOffsetProposedByDragGesture = safeXContentOffsetRange.clampingValue(xContentOffset + value.predictedEndTranslation.width)
    xContentOffset += value.translation.width
    withAnimation(isDragGestureLong() ? scrollingEaseOutAnimation : pagingAnimation) {
      xContentOffset = xContentOffsetFocusingItem(closestTo: xContentOffsetProposedByDragGesture)
    }
    
  }
  
}


struct DodoCarouselView_Previews: PreviewProvider {
  
  struct TestItem: Identifiable {
    var id: String { imageName + String(c) }
    let imageName: String
    let c: Int
  }
  
  static let testItems: [TestItem] = [
    TestItem(imageName: "banner1", c: 1),
    TestItem(imageName: "banner2", c: 1),
    TestItem(imageName: "banner3", c: 1),
    TestItem(imageName: "banner4", c: 1),
    TestItem(imageName: "banner1", c: 2),
    TestItem(imageName: "banner2", c: 2),
    TestItem(imageName: "banner3", c: 2),
    TestItem(imageName: "banner4", c: 2)
  ]
  
  static var previews: some View {
    DodoCarouselView(items: testItems, spacing: 8) { item in
      Image(item.imageName, bundle: Bundle.module)
        .resizable()
        .frame(width: 384, height: 192)
        .cornerRadius(10)
    }
  }
}
