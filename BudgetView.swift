import SwiftUI

struct BudgetView: View {
    @State private var income = "760"
    var body: some View {
        VStack(spacing: 20) {
            Text("Budgetkonfiguration").font(.title).foregroundColor(.purple)
            TextField("Einkommen eingeben", text: $income)
                .padding().background(Color.gray.opacity(0.3)).cornerRadius(8)
            Text("Formel: \(income)€ - 100€ Rücklage - 100€ Spaß - 150€ Business")
                .foregroundColor(.white)
            Spacer()
        }.padding().background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
