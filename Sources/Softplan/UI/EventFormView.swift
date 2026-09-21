import Foundation
import SwiftUI

/// A focused modal editor for creating or updating a plan.
struct EventFormView: View {
    @EnvironmentObject private var model: AppModel

    @State private var draft: PlanEvent
    @State private var showDetails: Bool
    @State private var showingCalendar = false
    @State private var calendarEndpoint: DateRangeEndpoint = .start
    private let isNew: Bool

    init(state: EditorState) {
        _draft = State(initialValue: state.draft)
        _showDetails = State(initialValue:
            !state.draft.location.isEmpty ||
            !state.draft.category.isEmpty ||
            !state.draft.tags.isEmpty
        )
        isNew = state.isNew
    }

    private static let dateFormatter = DayMath.formatter(for: "d MMM yyyy")

    private var startDate: Binding<Date> {
        Binding(
            get: { DayMath.date(from: draft.startDay) },
            set: { newValue in
                draft.startDay = DayMath.day(from: newValue)
                if draft.endDay < draft.startDay { draft.endDay = draft.startDay }
            }
        )
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { DayMath.date(from: draft.endDay) },
            set: { newValue in
                draft.endDay = max(DayMath.day(from: newValue), draft.startDay)
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(UI.controlBorder)

            if showingCalendar {
                DateRangePicker(
                    startDate: startDate,
                    endDate: endDate,
                    initialEndpoint: calendarEndpoint
                ) {
                    showingCalendar = false
                }
            } else {
                ScrollView(showsIndicators: false) {
                    formContents
                        .padding(20)
                }
                .frame(maxHeight: showDetails ? 430 : 355)

                Divider().overlay(UI.controlBorder)
                footer
            }
        }
        .frame(width: showingCalendar ? 620 : 500)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.2), radius: 34, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(UI.inputBorder, lineWidth: 1)
        )
        .accessibilityAddTraits(.isModal)
        .environment(\.colorScheme, .light)
        .animation(.easeInOut(duration: 0.18), value: showingCalendar)
        .onExitCommand {
            if showingCalendar {
                showingCalendar = false
            } else {
                model.editorState = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if showingCalendar {
                Button {
                    showingCalendar = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(UI.labelPrimary)
                        .frame(width: 30, height: 30)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Back to plan")
                .accessibilityLabel("Back to plan")
            }

            Text(showingCalendar ? "Select dates" : (isNew ? "Add plan" : "Edit plan"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(UI.labelPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                model.editorState = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(UI.labelSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var formContents: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                dateField("From", date: startDate, endpoint: .start)
                dateField("To", date: endDate, endpoint: .end)
            }

            VStack(alignment: .leading, spacing: 5) {
                fieldLabel("Plan name")
                TextField("e.g. Website launch", text: $draft.title)
                    .accessibilityLabel("Plan name")
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(UI.labelPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(inputBackground)
            }

            VStack(alignment: .leading, spacing: 5) {
                fieldLabel("Description")
                ZStack(alignment: .topLeading) {
                    if draft.notes.isEmpty {
                        Text("Add details")
                            .font(.system(size: 14))
                            .foregroundColor(UI.labelSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $draft.notes)
                        .accessibilityLabel("Description")
                        .font(.system(size: 14))
                        .foregroundColor(UI.labelPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(7)
                }
                .frame(height: 68)
                .background(inputBackground)
            }

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Color")
                colorDots
            }

            detailsDisclosure

            if showDetails {
                detailsFields
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if !isNew {
                Button("Delete", role: .destructive) {
                    model.delete(draft.id)
                    model.editorState = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
            }

            Spacer()

            Button {
                model.editorState = nil
            } label: {
                Text("Cancel")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(UI.labelPrimary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(UI.controlBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)

            Button {
                model.save(draft)
                model.editorState = nil
            } label: {
                Text(isNew ? "Add plan" : "Save")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(canSave ? UI.labelPrimary : UI.controlBorder)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var detailsFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                detailField("Location", text: $draft.location)
                detailField("Category", text: $draft.category)
            }
            detailField("Tags", text: $draft.tags)
        }
    }

    private var detailsDisclosure: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                showDetails.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Additional details")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UI.labelPrimary)
                    Text("Optional location, category and tags")
                        .font(.system(size: 11))
                        .foregroundColor(UI.labelSecondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(UI.labelSecondary)
                    .rotationEffect(.degrees(showDetails ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background(inputBackground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Additional details")
        .accessibilityValue(showDetails ? "Expanded" : "Collapsed")
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(UI.inputFill)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(UI.inputBorder, lineWidth: 1)
            )
    }

    private func dateField(
        _ title: String,
        date: Binding<Date>,
        endpoint: DateRangeEndpoint
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            fieldLabel(title)
            Button {
                calendarEndpoint = endpoint
                showingCalendar = true
            } label: {
                HStack(spacing: 8) {
                    Text(Self.dateFormatter.string(from: date.wrappedValue))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(UI.labelPrimary)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(UI.labelSecondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(inputBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) date")
            .accessibilityValue(Self.dateFormatter.string(from: date.wrappedValue))
            .accessibilityHint("Opens the calendar")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(UI.labelSecondary)
            .accessibilityHidden(true)
    }

    private func detailField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(UI.labelSecondary)
                .accessibilityHidden(true)
            TextField(title, text: text)
                .accessibilityLabel(title)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(UI.labelPrimary)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(inputBackground)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var colorDots: some View {
        HStack(spacing: 0) {
            ForEach(Palette.colors) { c in
                Button {
                    draft.paletteId = c.id
                } label: {
                    Circle()
                        .fill(c.accent)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .strokeBorder(
                                    draft.paletteId == c.id ? UI.labelPrimary : .clear,
                                    lineWidth: 2
                                )
                                .padding(-4)
                        )
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(c.name)
                .accessibilityLabel(c.name)
                .accessibilityAddTraits(draft.paletteId == c.id ? [.isSelected] : [])
            }
        }
        // The visible "Color" caption is hidden from assistive technology, so
        // name the row itself or the swatches arrive unannounced.
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Color")
    }
}
