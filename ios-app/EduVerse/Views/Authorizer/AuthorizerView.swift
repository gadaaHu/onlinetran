import SwiftUI

struct AuthorizerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var api = APIService.shared

    @State private var students: [StudentSummary] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var toastMessage: String? = nil
    @State private var searchQuery: String = ""
    @State private var selectedFilter: AuthorizerFilter = .all

    enum AuthorizerFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        var id: String { rawValue }
    }

    var filteredStudents: [StudentSummary] {
        students.filter { student in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .pending: matchesFilter = !student.isConfirmed
            case .approved: matchesFilter = student.isConfirmed
            }

            if !matchesFilter { return false }

            if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return true
            }

            let q = searchQuery.lowercased()
            let name = (student.fullName ?? "").lowercased()
            let email = student.email.lowercased()
            return name.contains(q) || email.contains(q)
        }
    }

    var pendingCount: Int { students.filter { !$0.isConfirmed }.count }
    var approvedCount: Int { students.filter { $0.isConfirmed }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0F0F1A").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Stats Summary Bar
                    HStack(spacing: 12) {
                        StatBadge(title: "Pending", count: pendingCount, color: Color(hex: "F59E0B"), icon: "clock.fill")
                        StatBadge(title: "Approved", count: approvedCount, color: Color(hex: "10B981"), icon: "checkmark.seal.fill")
                        StatBadge(title: "Total", count: students.count, color: Color(hex: "6366F1"), icon: "person.2.fill")
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    // Filter Pills & Search
                    VStack(spacing: 10) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("Search by name or email...", text: $searchQuery)
                                .foregroundColor(.white)
                                .font(.system(size: 14))
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "1A1A2E"))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))

                        // Filter Pills
                        HStack(spacing: 8) {
                            ForEach(AuthorizerFilter.allCases) { filter in
                                Button(action: { selectedFilter = filter }) {
                                    Text("\(filter.rawValue) \(filter == .pending ? "(\(pendingCount))" : "")")
                                        .font(.system(size: 12, weight: selectedFilter == filter ? .bold : .medium))
                                        .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.6))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            selectedFilter == filter
                                                ? Color(hex: "6366F1")
                                                : Color(hex: "1A1A2E")
                                        )
                                        .cornerRadius(20)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                    // Toast Feedback
                    if let toast = toastMessage {
                        HStack {
                            Image(systemName: "info.circle.fill")
                            Text(toast)
                                .font(.system(size: 13))
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(hex: "10B981").opacity(0.2))
                        .foregroundColor(Color(hex: "10B981"))
                        .cornerRadius(8)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    }

                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "6366F1")))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if let err = errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "EF4444"))
                            Text(err)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            Button("Retry") { loadData() }
                                .buttonStyle(.borderedProminent)
                                .tint(Color(hex: "6366F1"))
                        }
                        .padding(24)
                        Spacer()
                    } else if filteredStudents.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 44))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No students match criteria")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredStudents) { student in
                                    StudentRowCard(
                                        student: student,
                                        onConfirm: { confirmStudent(student) },
                                        onReject: { rejectStudent(student) }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle("Authorizer Portal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "0F0F1A"), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { loadData() }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color(hex: "6366F1"))
                    }
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let fetched = try await api.getStudents()
                students = fetched
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func confirmStudent(_ student: StudentSummary) {
        Task {
            do {
                let msg = try await api.confirmStudent(userId: student.id)
                showToast(msg)
                if let idx = students.firstIndex(where: { $0.id == student.id }) {
                    let old = students[idx]
                    students[idx] = StudentSummary(
                        id: old.id,
                        email: old.email,
                        firstName: old.firstName,
                        lastName: old.lastName,
                        fullName: old.fullName,
                        isConfirmed: true,
                        roles: old.roles,
                        createdAt: old.createdAt
                    )
                }
            } catch {
                showToast("Failed to confirm: \(error.localizedDescription)")
            }
        }
    }

    private func rejectStudent(_ student: StudentSummary) {
        Task {
            do {
                let msg = try await api.rejectStudent(userId: student.id)
                showToast(msg)
                if let idx = students.firstIndex(where: { $0.id == student.id }) {
                    let old = students[idx]
                    students[idx] = StudentSummary(
                        id: old.id,
                        email: old.email,
                        firstName: old.firstName,
                        lastName: old.lastName,
                        fullName: old.fullName,
                        isConfirmed: false,
                        roles: old.roles,
                        createdAt: old.createdAt
                    )
                }
            } catch {
                showToast("Failed to reject: \(error.localizedDescription)")
            }
        }
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if toastMessage == msg {
                toastMessage = nil
            }
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "1A1A2E"))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Student Row Card
struct StudentRowCard: View {
    let student: StudentSummary
    let onConfirm: () -> Void
    let onReject: () -> Void

    var initials: String {
        let parts = (student.fullName ?? student.email).split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String((student.fullName ?? student.email).prefix(2)).uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(student.isConfirmed ? Color(hex: "10B981").opacity(0.2) : Color(hex: "F59E0B").opacity(0.2))
                        .frame(width: 44, height: 44)
                    Text(initials)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(student.isConfirmed ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(student.fullName ?? "Student")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(student.email)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(student.isConfirmed ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                        .frame(width: 6, height: 6)
                    Text(student.isConfirmed ? "Approved" : "Pending")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(student.isConfirmed ? Color(hex: "10B981") : Color(hex: "F59E0B"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (student.isConfirmed ? Color(hex: "10B981") : Color(hex: "F59E0B")).opacity(0.12)
                )
                .cornerRadius(8)
            }

            // Actions Divider
            Divider().background(Color.white.opacity(0.08))

            // Action Buttons
            HStack(spacing: 10) {
                if !student.isConfirmed {
                    Button(action: onConfirm) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Confirm & Authorize")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color(hex: "10B981"))
                        .cornerRadius(8)
                    }

                    Button(action: onReject) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                            Text("Reject")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "EF4444"))
                        .frame(width: 80, height: 36)
                        .background(Color(hex: "EF4444").opacity(0.12))
                        .cornerRadius(8)
                    }
                } else {
                    Button(action: onReject) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.seal")
                            Text("Revoke Authorization")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "F87171"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color(hex: "EF4444").opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "1A1A2E"))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(student.isConfirmed ? Color.white.opacity(0.06) : Color(hex: "F59E0B").opacity(0.3), lineWidth: 1)
        )
    }
}
