//
//  ContentView.swift
//  Demo
//
//  Created by Илья Бойков on 19.02.2021.
//

import SwiftUI
import DodoCarouselView

struct TestItem: Identifiable {
  var id: String { imageName + String(c) }
  let imageName: String
  let c: Int
}

let testItems: [TestItem] = [
  TestItem(imageName: "banner1", c: 1),
  TestItem(imageName: "banner2", c: 1),
  TestItem(imageName: "banner3", c: 1),
  TestItem(imageName: "banner4", c: 1),
  TestItem(imageName: "banner1", c: 2),
  TestItem(imageName: "banner2", c: 2),
  TestItem(imageName: "banner3", c: 2),
  TestItem(imageName: "banner4", c: 2)
]




struct ContentView: View {
  

  
    var body: some View {
      VStack {
        
        Text(
        """
            1
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
            2
        """
        )
        
        DodoCarouselView(items: testItems, spacing: 24) { item in
          Image(item.imageName, bundle: Bundle.main)
            .resizable()
            .frame(width: 384, height: 192)
            .cornerRadius(10)
        }
        
      }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
