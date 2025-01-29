import SwiftUI

extension UIApplication {
    /// Ends editing (hides the keyboard) by sending a resignFirstResponder action.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Attach this modifier to a container to dismiss the keyboard on any tap outside of a TextField.
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}

