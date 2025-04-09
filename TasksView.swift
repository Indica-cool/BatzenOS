import SwiftUI

struct TasksView: View {
    @State private var isCompleted = false
    var body: some View {
        VStack(spacing: 20) {
            Text("Tagesaufgaben").font(.title).foregroundColor(.purple)
            Toggle("Fixkosten geprüft", isOn: $isCompleted).foregroundColor(.white)
            Spacer()
        }.padding().background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
