import SwiftUI
import AVFoundation

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Restbudget: 410€")
                .font(.title)
                .foregroundColor(.purple)
            ProgressView("Rücklage", value: 100, total: 760)
                .accentColor(.green)
            ProgressView("Spaßgeld", value: 100, total: 760)
                .accentColor(.purple)
            ProgressView("Business-Budget", value: 150, total: 760)
                .accentColor(.green)
            Button("Sprachfeedback") {
                speak(text: "Du hast heute noch 410 Euro zur Verfügung.")
            }.foregroundColor(.white).padding().background(Color.purple).cornerRadius(8)
        }
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
