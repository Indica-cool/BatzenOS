import SwiftUI

struct FlipAssistantView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Flip-Assistant").font(.title).foregroundColor(.purple)
            Text("KI-basierte Flip-Strategien.").foregroundColor(.white)
            Spacer()
        }.padding().background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
