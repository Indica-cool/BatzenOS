import SwiftUI

struct ChatGPTView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("ChatGPT Assistant").font(.title).foregroundColor(.purple)
            Text("Fragen stellen für deine Strategien.").foregroundColor(.white)
            Spacer()
        }.padding().background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
