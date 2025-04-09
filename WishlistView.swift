import SwiftUI

struct WishlistView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Wunschliste & Invest").font(.title).foregroundColor(.purple)
            Text("Hier prüfst du deine Wünsche.").foregroundColor(.white)
            Spacer()
        }.padding().background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
