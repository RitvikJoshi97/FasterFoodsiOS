import Foundation
import SwiftUI

struct ExpandedGamePlanView: View {
    let markdown: String
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastService: ToastService
    @State private var isFeedbackPresented = false
    @State private var isAddPresented = false
    @State private var isReportPresented = false
    @State private var reportText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(GamePlanMarkdownRenderer.attributed(from: markdown))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineSpacing(8)
                        .textSelection(.enabled)

                    Divider()

                    HStack(spacing: 12) {
                        Button("Feedback") {
                            isFeedbackPresented = true
                        }
                        .buttonStyle(.bordered)

                        Button("Add") {
                            isAddPresented = true
                        }
                        .buttonStyle(.bordered)

                        Button("Report") {
                            isReportPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Game Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $isFeedbackPresented) {
            VStack(spacing: 16) {
                Text("How do you feel about this game plan?")
                    .font(.headline)

                HStack(spacing: 24) {
                    Button {
                        isFeedbackPresented = false
                        toastService.show("Thanks for the feedback!")
                    } label: {
                        Text("👍")
                            .font(.system(size: 36))
                    }

                    Button {
                        isFeedbackPresented = false
                        toastService.show("Thanks for the feedback!")
                    } label: {
                        Text("👎")
                            .font(.system(size: 36))
                    }
                }
                .tint(Color.accentColor)
            }
            .padding(24)
            .presentationDetents([.height(200)])
        }
        .alert("Add", isPresented: $isAddPresented) {
            Button("Close", role: .cancel) {}
        } message: {
            Text(
                "We are working on a way to address further feelings about your game plan. Bear with us."
            )
        }
        .sheet(isPresented: $isReportPresented) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Report an issue")
                        .font(.headline)
                    TextEditor(text: $reportText)
                        .frame(minHeight: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                    Spacer()
                }
                .padding()
                .navigationTitle("Report")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") {
                            isReportPresented = false
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Send") {
                            isReportPresented = false
                            toastService.show("Report sent. Thank you!")
                        }
                        .disabled(
                            reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}
