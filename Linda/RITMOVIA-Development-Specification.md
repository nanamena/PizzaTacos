# RITMOVIA — Complete iOS App Development Specification

You are an expert iOS developer, SwiftUI engineer, and Apple Human Interface Guidelines specialist.

I want you to help me develop **RITMOVIA**, a native iOS fitness organization and workout timer application.

This is not just a visual prototype. The goal is to build a functional, well-structured iOS application in Xcode, with working navigation, interactions, timers, data management, and reusable components.

Before writing any code, inspect the existing Xcode project, its architecture, assets, deployment target, and current implementation. Preserve existing working functionality. Do not delete or replace existing files unnecessarily. If the project already contains components or models, reuse them where appropriate.

---

# 1. APP IDENTITY

**App name:** RITMOVIA

**Tagline:** YOUR TIME. YOUR RHYTHM.

**Main purpose:**

RITMOVIA helps users organize their existing workout plans, manage their available training time, follow exercises with a focused timer, and track their consistency and personal training experience.

The app does NOT create professional training prescriptions or independently recommend exercises.

Users can:
- Import an existing workout plan.
- Scan a printed or handwritten training sheet.
- Create their own workout plan manually.
- Organize workouts by day.
- Select how much time they have available.
- Use a timer to follow their workout.
- Track completed workouts and training duration.
- Record how they felt after each workout.

**Important safety principle:**

RITMOVIA is a workout organization and timer tool, not a personal trainer or medical application.

Never automatically change prescribed weights, repetitions, sets, or rest periods. Never invent exercises or claim that a modified workout is professionally recommended.

If a workout cannot fit into the available time, clearly explain this and let the user decide how to proceed. Any proposed scheduling adjustment must preserve the original training instructions unless the user explicitly edits their plan.

---

# 2. TECHNOLOGY AND DEVELOPMENT REQUIREMENTS

Use:
- Swift
- SwiftUI
- Native iOS components
- MVVM architecture, where appropriate
- SwiftData for persistent local storage, if compatible with the existing project
- PhotosPicker for selecting images
- FileImporter for importing PDF documents
- Vision / VisionKit for text recognition and document scanning, where supported
- AVFoundation only when camera functionality is needed
- HealthKit for optional Apple Health integration
- UserNotifications for workout reminders, with user permission

Prefer native Apple frameworks and components.

Requirements:
- Support current iPhone screen sizes. Adapt layouts for iPad using available space and appropriate navigation patterns. Provide a companion Apple Watch experience for active workout timing and essential workout controls, with suitable synchronization between devices.
- Respect safe areas and Dynamic Island.
- Support Light Mode and Dark Mode.
- Use accessible colors and sufficient contrast.
- Support Dynamic Type where practical.
- Make controls large enough to use during exercise.
- Avoid unnecessary third-party dependencies.
- Use reusable SwiftUI components.
- Keep the interface responsive and fluid.

**LANGUAGE REQUIREMENTS:**

The entire app interface must be in English.

All:
- Screen titles
- Buttons
- Navigation labels
- Exercise labels
- Error messages
- Empty states
- Confirmation messages
- Accessibility labels

must be written in natural, professional English.

However, ALL explanatory code comments must be written in Spanish.

Example:

```swift
// Este estado controla si el cronómetro está activo.
@State private var isTimerRunning = false
```

Keep variable names, function names, model names, and file names in English.

---

# 3. VISUAL DESIGN SYSTEM

Create a polished, premium Apple-inspired fitness interface.

The visual direction should feel:
- Modern
- Sporty
- Clean
- Energetic
- Friendly
- Professional
- Minimalist

Use native SwiftUI design patterns and subtle Liquid Glass-inspired materials where appropriate.

Use an Apple-inspired interface that follows the supplied screen designs. Use solid colors throughout the app UI; do not use gradients in screens, buttons, cards, or navigation. Reserve gradients for the widget only. Prioritize readability and usability.

## Color palette

Use this fixed brand palette:

- Power Red: #F04424
- Energy Orange: #FF781F
- Dark Brown: #642A25
- Warm White: #FFF7F3
- Soft Cream: #F8EEE9
- Primary Text: #211B19
- Secondary Text: #786B66
- Card Border: #EADBD4

Light Mode:
- Warm White or Soft Cream backgrounds.
- White cards.
- Dark primary text.
- Orange and red for actions, active states, progress, and highlights.

Dark Mode:
- Deep brown or near-black backgrounds.
- Elevated dark surfaces.
- White primary text.
- Muted secondary text.
- Keep the same red and orange brand accents.

Do not use a completely different palette in Dark Mode.

## Typography

Use Apple's SF Pro system typography.

Use:
- Bold and large screen titles.
- Medium-weight section titles.
- Regular body text.
- Clear numerical typography for timers and statistics.

## Mascot

Use the existing official RITMOVIA ice cream mascot.

The mascot has:
- Cream-colored ice cream head.
- Red bandana.
- Waffle cone body.
- Small athletic body and sneakers.
- Expressive facial reactions.

IMPORTANT:
Do not redesign or replace the official mascot.

First inspect the project's Assets catalog and identify available mascot images.

If the assets are missing, create reusable image placeholders with clearly named asset references. Do not generate random replacement characters.

The mascot can appear in:
- Workout summaries.
- Rest periods.
- Workout completion.
- Empty states.
- Progress celebrations.

Avoid placing a large mascot on every screen. It must never compete with the timer or important information.

---

# 4. MAIN NAVIGATION

The app has ONLY THREE main navigation tabs:

1. Workouts
2. Progress
3. Settings

Use a native-looking bottom tab bar.

The selected tab must use the brand accent color.

The app must not add a separate Profile tab. Profile belongs inside Settings.

The Focus Workout screen, Add Workout sheet, Scan flow, and Create Workout form are secondary screens presented from the main navigation.

Suggested navigation structure:

```text
RITMOVIA
│
├── Workouts
│   ├── Add Workout
│   │   ├── Scan Workout Plan
│   │   └── Create Manually
│   ├── Today's Exercises
│   └── Focus Workout
│       └── Workout Completion
│
├── Progress
│
└── Settings
    ├── Profile
    ├── Appearance
    ├── Permissions & Integrations
    ├── Workout Preferences
    ├── Notifications
    └── About
```

Use NavigationStack and appropriate sheet presentations.

---

# 5. SCREEN ONE — WORKOUTS (HOME)

This is the main screen of RITMOVIA.

It should immediately communicate:
- Who is using the app.
- What workout is scheduled for today.
- How many exercises are assigned.
- How much time the workout is expected to take.
- How much time the user has available today.

## A. Header

Display:

"Hello, [User Name]!"

"Workouts"

Place a circular + button in the upper-right corner.

The + button opens the Add Workout bottom sheet.

Use a personalized greeting, but do not force a specific time-based greeting if the time is unavailable.

## B. Today's Workout card

Display the workout assigned to the current day.

Example:

Today's Workout

Upper Body

5 exercises

~28 min (estimated)

Show the mascot in a motivating pose.

If the user has multiple workout sessions assigned to that day, show the appropriate workout or allow switching between them.

If no workout is scheduled:

"Rest Day"

"Enjoy your recovery. Your next workout is waiting for you."

Provide an action to view the weekly plan or add a workout.

If no plan exists at all, show an onboarding empty state:

"Your workouts start here."

"Add your training plan to organize your sessions."

## C. Available Time selector

This is one of the most important functions of the app.

Display:

"How much time do you have today?"

"We'll organize your workout around your available time."

Provide:
- Minus button.
- Large numerical time value.
- Plus button.
- Slider for selecting available minutes.

Example:

30 min

Allow a configurable range, with a sensible minimum and maximum.

Use sensible increments, such as 5 minutes.

The selected value must update immediately.

## D. Start Workout button

Large primary button:

"Start Workout"

When tapped:
1. Read today's assigned workout.
2. Read the selected available time.
3. Calculate the estimated workout duration using the saved exercises, sets, repetitions or exercise durations, and rest periods.
4. Check whether the planned session fits within the available time.
5. Present a clear workout preview before starting when appropriate.
6. Navigate to Focus Workout.

Do not silently remove exercises or change training prescriptions.

If the session exceeds the available time, show a clear message and allow the user to decide whether to start the full session, adjust their available time, or review the plan.

## E. Today's Exercises

Display a section:

"Today's Exercises"

Show the exercises assigned for the current day.

Each exercise row should display:
- Exercise name.
- Exercise icon or illustration.
- Number of sets.
- Repetitions or exercise duration.
- Optional prescribed weight.
- Chevron to open exercise details.

Example:

Bench Press
4 sets × 10 reps

Lat Pulldown
3 sets × 12 reps

Shoulder Press
3 sets × 10 reps

Provide:

"See all"

This opens the complete exercise list for the current workout.

## F. Add Workout button (+)

When the + button is tapped, show a native-looking bottom sheet.

Title:

"Add Workout"

Subtitle:

"Choose how to add your training plan."

There must be ONLY TWO main options:

1. Scan Workout Plan
2. Create Manually

Do not add a separate PDF option here. PDF importing belongs inside Scan Workout Plan.

---

# 6. ADD WORKOUT FLOW

## A. Scan Workout Plan

Display:

"Scan Workout Plan"

"Import your existing training plan."

Provide three import methods:

- Take Photo
- Choose from Photos
- Browse Files

Implementation:
- Take Photo: use a native document camera/scanning experience when supported.
- Choose from Photos: use PhotosPicker.
- Browse Files: use FileImporter and support PDF and image formats where practical.

For document scanning, use VisionKit where supported.

For OCR, use Apple's Vision framework.

Extract available information such as:
- Workout day.
- Exercise name.
- Sets.
- Repetitions.
- Exercise duration.
- Rest time.
- Weight.
- Additional notes.

Do not assume all documents have the same format.

## B. Scan Review screen

After scanning, NEVER save the recognized information automatically.

Show a review screen:

"Review Your Workout"

Display the recognized exercises in editable fields.

Allow the user to:
- Correct exercise names.
- Edit sets.
- Edit repetitions.
- Edit duration.
- Edit rest time.
- Edit weight.
- Assign exercises to a day.
- Remove incorrect entries.
- Add missing entries.

Show recognition uncertainty where appropriate.

Buttons:

"Save Workout"

"Scan Again"

The user must confirm the extracted information before saving.

If OCR fails, show:

"We couldn't read this workout clearly."

"Try another photo or add your exercises manually."

Never invent missing workout data.

---

# 7. CREATE MANUALLY SCREEN

This screen allows users to build their own workout using simple form fields.

The design should be clean and efficient, with minimal distractions.

## A. Header

Back button.

Title:

"Create Workout"

## B. Workout name

Label:

"Workout Name"

Placeholder:

"e.g. Upper Body, Push Day"

Allow the user to assign the workout to a weekday or schedule it later.

## C. Exercises section

Title:

"Exercises"

Button:

"+ Add Exercise"

Each exercise should be represented by an editable card.

Each exercise card must contain:

Exercise Name

Placeholder:
"e.g. Bench Press"

Exercise Type:
- Reps
- Time

When Reps is selected, show:

Sets

Reps

Rest

When Time is selected, show:

Sets

Exercise Duration

Rest

Use clear input fields and numeric controls.

Example:

Exercise Name: Bench Press

Type: Reps

Sets: 4

Reps: 10

Rest: 60 seconds

Another example:

Exercise Name: Plank

Type: Time

Sets: 3

Duration: 45 seconds

Rest: 30 seconds

Optional fields:
- Weight.
- Notes.

Weight must never be mandatory.

Each exercise card should support:
- Edit.
- Delete.
- Duplicate.
- Reorder.

Use a native-feeling interface. Avoid excessive tiny buttons.

## D. Add Exercise

When the user taps "+ Add Exercise", create another empty exercise card.

The user must be able to add and remove multiple exercises.

## E. Estimated Workout Time

Automatically calculate:

"Estimated Time"

"Includes rest periods"

The calculation should consider:
- Number of sets.
- Repetitions or exercise duration.
- Rest periods.
- Any configured time estimates where available.

If the exercise is repetition-based and no duration is known, do not pretend the exact duration is known. Use an explicitly labeled estimate or mark the duration as approximate.

Display the total as an estimate.

Also show:
- Total Sets.
- Total Reps, where applicable.
- Total Rest Time.

## F. Bottom actions

Primary button:

“Done”

Also provide an “Add Exercise” action so the user can create as many exercise cards as needed.

Let the user choose the plan duration: 2 weeks, 1 month, 3 months, 6 months, or ongoing. Store the selected duration with the plan.

When “Done” is tapped:
- Validate required fields.
- Save the workout locally.
- Show confirmation.
- Return to Workouts.
- Make the workout available in the user's schedule.

Do not automatically start the workout when saving.

If the user has not entered a name or at least one valid exercise, show a helpful validation message.

---

# 8. SCREEN TWO — FOCUS WORKOUT

This is the most important active workout experience.

The user should be able to operate the app quickly while exercising.

The design should be highly focused, with:
- A large timer.
- Large touch targets.
- Clear exercise information.
- Minimal distractions.
- The mascot reacting to the current workout state.

The screen must adapt to both repetition-based and time-based exercises.

## A. Header

Back button.

Title:

"Workout"

Optional more menu:
- Pause Workout.
- End Workout.
- Workout Details.

Show the workout name:

"Upper Body"

"Workout 2 of 5"

Show a progress bar indicating overall workout progress.

## B. Mascot area

Show the official RITMOVIA mascot.

Possible states:
- Motivated during an exercise.
- Relaxed during rest.
- Tired after completing a difficult session.
- Celebrating after finishing the workout.

Use existing mascot assets only.

If an animation asset does not exist, use a subtle native SwiftUI animation such as a gentle bounce or scale effect. Do not require complex animation systems.

## C. Timer area

Use a large circular progress indicator.

The timer must clearly show the current state:

"Exercise"

or

"Rest"

Display the remaining time in large numbers.

Example:

00:36

Include a pause/resume control.

The ring should update smoothly as time passes.

The timer must use a reliable time-based implementation. Avoid relying exclusively on a repeating UI animation for elapsed time.

Timer requirements:
- Start.
- Pause.
- Resume.
- Skip rest.
- Finish exercise.
- Move to next exercise.
- Handle app backgrounding and foregrounding correctly.
- Prevent multiple timers from running simultaneously.

Store the actual start time and remaining duration so the timer can recover correctly when the app becomes inactive.

## D. Repetition-based exercises

For repetition-based exercises, show:
- Exercise name.
- Current set.
- Total sets.
- Repetitions.
- Prescribed weight, if available.
- Rest duration.

Example:

Bench Press

Set 2 of 4

10 reps

20 kg

When a set is completed:
1. Mark the set completed.
2. Start the configured rest timer.
3. Display the Rest state.
4. Show the next set or next exercise.
5. Allow the user to skip rest.

The user must be able to pause and resume.

Do not automatically mark repetitions as completed without user interaction.

## E. Time-based exercises

For time-based exercises, display:

Exercise Duration

Example:

Plank

00:45

Start the exercise timer.

When the duration reaches zero:
- Mark the exercise set completed.
- Enter the rest period if configured.
- Continue according to the workout sequence.

## F. Rest state

Display:

"Rest"

A large countdown.

Example:

00:36

The mascot should use a relaxed expression.

Show:

"Next Exercise"

Example:

Lat Pulldown

3 sets × 10 reps

Button:

"Skip Rest"

The user should also be able to pause the timer.

## G. Voice guidance

Provide optional spoken workout cues during an active workout, such as exercise changes, set completion, rest countdown milestones, and timer completion. Include a user setting to enable or disable voice cues. Do not require microphone access for text-to-speech guidance.

## H. Remaining workout time

Display:

"Time Remaining"

Example:

~24:36

This is an estimate based on remaining exercises and rest periods.

Update it as the workout progresses.

Make clear that it is an estimate.

## I. Workout controls

Provide:
- Pause/Resume.
- Skip Rest.
- Previous Exercise, where appropriate.
- Next Exercise.
- Finish Workout.

Require confirmation before ending a workout early.

Do not accidentally lose completed sets when navigating away.

## J. Workout completion

When all planned exercises are completed, show a completion screen.

Title:

"Workout Complete!"

Subtitle:

"Great work. Every session counts."

Display:
- Total workout time.
- Exercises completed.
- Sets completed.
- Planned versus actual duration, when available.

Show the mascot celebrating.

Primary button:

"Continue"

Then ask:

"How did you feel after your workout?"

Allow one primary feeling selection:

- Good
- Tired
- Sore
- Heavy

Optional additional selection:
- Energized
- Normal
- Stressed

Allow an optional short note.

Store this feedback with the workout session.

This is subjective personal feedback, not a medical diagnosis or physical assessment.

Button:

"Save & Finish"

After saving, update Progress.

---

# 9. SCREEN THREE — PROGRESS

Title:

"Progress"

Subtitle:

"Your training at a glance."

This screen should communicate the user's consistency and personal workout history.

## A. Period selector

Provide three options:

- Week
- Month
- Year

The selected period must update all statistics and visualizations.

Also provide navigation between previous and current periods.

Example:

Nov 11 – Nov 17

Do not show hardcoded sample statistics in the real application.

If there is no data, show an informative empty state.

## B. Activity Summary

Show two primary cards:

Training Days

Average Training Time

Also show Total Training Time as a secondary statistic.

Week:
- Number of days trained.
- Average session duration.
- Total time this week.

Month:
- Number of training days.
- Average time per session.
- Total monthly duration.

Year:
- Total sessions.
- Total hours.
- Monthly consistency trends.

Calculate these from real saved workout sessions.

## C. Muscle Training

Title:

"Muscle Training"

Subtitle:

"Trained areas this period."

Use a front and back human muscular model, if the appropriate assets are available.

Highlight muscle groups based on the exercises that the user has recorded in their plans and completed sessions.

Show:
- Back.
- Shoulders.
- Arms.
- Chest.
- Core.
- Glutes.
- Legs.

Week:
Show muscle groups trained during the selected week.

Month:
Show training frequency by muscle group during the month.

Year:
Show accumulated frequency and trends across the year.

Important:
Only display muscle information that is explicitly associated with the user's saved exercise data. Do not infer medical or physiological outcomes.

If no muscle metadata exists, show the available training history without inventing muscle activation data.

## D. Training Consistency

Title:

"Training Consistency"

Week:
Show Monday through Sunday, with completed training days marked.

Month:
Show a calendar with completed workout days.

Year:
Show a monthly consistency overview.

Use subtle visual indicators.

Do not treat scheduled rest days as missed workouts.

## E. How You Felt

Title:

"How You Felt"

Subtitle:

"Your feedback after each workout."

Display the percentage of recorded sessions associated with each feeling:

- Good
- Tired
- Sore
- Heavy

Allow the user to tap a category to see the related sessions.

Show trends over the selected period.

Never interpret this data as a medical diagnosis.

## F. Training History

Provide access to previous workout sessions.

Each session should show:
- Date.
- Workout name.
- Duration.
- Completion status.
- Exercises completed.

Tapping a session opens its details.

All statistics must be derived from saved data, not static mock values.

---

# 10. SCREEN FOUR — SETTINGS

Title:

"Settings"

Subtitle:

"Customize your training experience."

## A. Profile

Show:
- Profile image.
- User name.
- "View and edit your profile."

Allow editing basic profile information.

Do not require personal information that is not necessary for the application.

## B. Appearance

Title:

"Appearance"

Subtitle:

"App appearance and style."

Options:

App Theme:
- Light
- Dark
- System

Persist the selected theme.

The app must update immediately when the selection changes.

App Icon:
If alternate app icons are configured in the Xcode project, allow the user to select between available icons.

If alternate icons are not configured, do not display nonfunctional selection controls.

## C. Permissions & Integrations

Title:

"Permissions & Integrations"

Subtitle:

"Manage app access and connected services."

Include:

Camera:
"Scan your workout plans."

Photos:
"Choose workout images and documents."

Microphone:
"Enable voice features."

Audio:
"Manage app sounds and timer alerts."

Apple Health:
"Sync your workouts and activity data."

Accessibility:
"VoiceOver and accessibility options."

Important:
Do not treat VoiceOver as a separate system permission. The app must support VoiceOver through accessible labels, hints, and semantic controls.

Request permissions only when the user activates the feature that requires them.

Show connection status where appropriate.

For Apple Health:
- Request only the HealthKit permissions actually needed.
- Explain what data is accessed.
- Allow the user to connect or disconnect.
- Never claim that synchronization is active if permission has not been granted.
- Handle unavailable HealthKit devices or permissions gracefully.

Do not request microphone access unless actual microphone functionality is implemented.

## D. Workout Preferences

Title:

"Workout Preferences"

Allow users to configure:
- Default Rest Time.
- Default Sets.
- Auto-Next Exercise.
- Default timer behavior.

Example:
Default Rest Time: 60 seconds
Default Sets: 3

Auto-Next Exercise should be optional and disabled or enabled according to the user's preference.

## E. Notifications

Allow:
- Workout reminders.
- Scheduled training reminders.
- Optional progress notifications.

Request notification permission appropriately.

## F. About

Include:
- App Version.
- Privacy Policy.
- Terms of Service.
- Help & Support.

---

# 11. DATA MODELS

Design clean and maintainable models.

Suggested entities:

UserProfile
- id
- name
- profileImageData
- createdAt

WorkoutPlan
- id
- name
- scheduledDays
- exercises
- createdAt
- updatedAt

Exercise
- id
- name
- type (reps or time)
- sets
- repetitions
- duration
- restDuration
- weight
- notes
- orderIndex
- muscleGroup, if known

WorkoutSession
- id
- workoutPlanId
- startDate
- endDate
- actualDuration
- completed
- completedSets
- completedExercises
- availableTime
- feeling
- notes

WorkoutSet
- id
- exerciseId
- setNumber
- completed
- actualDuration
- completedAt

UserPreferences
- theme
- defaultRestTime
- defaultSets
- autoNextExercise
- notificationsEnabled
- soundEnabled

Use appropriate relationships and persistence.

Avoid duplicating workout plan data unnecessarily.

A workout plan and an actual workout session must be separate concepts.

Changing a future workout plan should not rewrite previously completed workout history.

---

# 12. WORKOUT TIME CALCULATION

Implement a dedicated, testable workout duration calculator.

For time-based exercises:

Total exercise time = sets × exercise duration.

For repetition-based exercises:
If a reliable duration estimate is unavailable, mark the estimate as approximate. Do not invent an exact exercise duration.

Rest time should be calculated according to the configured rest periods and actual sequence.

Do not automatically count a rest period after the final set unless the user explicitly configured it.

Display:

"Estimated Time"

"Actual Time"

Keep both values separate.

When available time is lower than estimated time:
- Clearly indicate the difference.
- Preserve the original workout.
- Let the user decide what to do.
- Never silently remove exercises or change the prescribed training.

---

# 13. DESIGN COMPONENTS TO REUSE

Create reusable SwiftUI components for:

- PrimaryButton
- SecondaryButton
- WorkoutCard
- ExerciseRow
- ExerciseEditorCard
- TimerRing
- TimeSelector
- ProgressCard
- MuscleTrainingCard
- FeelingSelector
- MascotView
- BottomNavigationBar
- SectionHeader
- EmptyStateView
- ConfirmationDialog

Use consistent corner radii, spacing, padding, and typography.

Use SF Symbols where appropriate.

Do not use emoji as replacements for core interface icons.

---

# 14. FUNCTIONALITY AND QUALITY REQUIREMENTS

Every visible button must perform its intended action.

Do not leave decorative buttons that appear functional but do nothing.

Provide:
- Form validation.
- Empty states.
- Error states.
- Confirmation dialogs.
- Loading states for document processing.
- Safe timer lifecycle management.
- Persistent user data.
- Correct navigation.
- Accessible controls.

The app must not crash if:
- The user has no workout plan.
- A document cannot be recognized.
- The user denies camera or photo access.
- HealthKit is unavailable.
- A timer is interrupted.
- A workout is ended early.

Avoid hardcoding example users, workout statistics, or completed sessions into production behavior.

Use sample data only for previews and SwiftUI development.

---

# 15. DEVELOPMENT WORKFLOW — VERY IMPORTANT

Do not try to implement the entire app in one massive code change.

Work incrementally.

**Phase 1 — Project inspection**
- Inspect the existing project.
- Identify the current architecture.
- Identify available assets.
- Explain which files can be reused.
- Identify missing resources.
- Propose the implementation structure.

**Phase 2 — Design system**
- Create reusable colors.
- Create typography styles.
- Create reusable buttons and cards.
- Implement Light Mode and Dark Mode.
- Add the mascot asset system.

**Phase 3 — Navigation and Workouts**
- Implement the three-tab navigation.
- Build the Workouts home screen.
- Implement the available-time selector.
- Implement the Add Workout sheet.

**Phase 4 — Manual workout creation**
- Implement editable exercise forms.
- Support reps and time-based exercises.
- Implement workout duration estimates.
- Persist saved plans.

**Phase 5 — Focus Workout**
- Implement the timer.
- Implement exercise and rest states.
- Implement set completion.
- Implement pause, resume, skip, and finish.
- Implement workout completion and feeling feedback.

**Phase 6 — Scanning**
- Implement camera/document scanning.
- Implement PhotosPicker.
- Implement PDF import.
- Implement OCR.
- Implement the review and correction workflow.

**Phase 7 — Progress**
- Connect real workout history.
- Implement weekly, monthly, and yearly views.
- Implement training consistency.
- Implement muscle training statistics.
- Implement feelings history.

**Phase 8 — Settings**
- Implement profile.
- Implement theme selection.
- Implement permissions and integrations.
- Implement Apple Health when the required capabilities are configured.
- Implement workout preferences and notifications.

**Phase 9 — Testing and polish**
- Test all navigation paths.
- Test timers and app lifecycle behavior.
- Test Light Mode and Dark Mode.
- Test empty states.
- Test data persistence.
- Fix compilation errors.
- Verify the app builds successfully.

---

# 16. HOW I WANT YOU TO WORK WITH ME

I am a Graphic Design student and I am responsible for the visual identity and UI/UX design of this application.

I want to develop the app collaboratively, screen by screen.

Please follow these rules:

1. First inspect the existing project and report what you find.
2. Do not redesign the app independently or change the approved visual direction.
3. Preserve the RITMOVIA mascot and brand identity.
4. Keep the UI in English.
5. Write all explanatory code comments in Spanish.
6. Explain technical decisions to me in Spanish.
7. Tell me which files you create or modify.
8. Do not implement future phases before we review the current phase.
9. Do not overwrite working code without explaining why.
10. Build and verify the project after each meaningful implementation stage, when the available environment allows it.
11. If an asset is missing, ask me for it or use a clearly named placeholder.
12. Do not claim that a feature works unless it has actually been implemented.

**Start with Phase 1: inspect my current Xcode project and report its architecture, existing assets, current implementation, and the recommended next steps. Do not start changing the entire project yet.**