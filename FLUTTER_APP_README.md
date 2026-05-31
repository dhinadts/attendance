# WorkSync Pro - Flutter App

A professional industrial-themed attendance and payroll management system built with Flutter using Material 3 design system.

## Project Overview

**WorkSync Pro** is a complete Flutter application with 4 essential screens for managing employee attendance, face authentication, and payroll reporting. The app follows the **Industrial-Professional** design system with high-contrast, clean UI optimized for diverse work environments.

## Features

✅ **4 Complete Screens:**
1. **Face Authentication Login** - Face scan circular frame with biometric UI
2. **Attendance GPS Tracking** - Check-in/out with GPS location verification
3. **Owner Dashboard** - Business summary, attendance stats, quick actions
4. **Salary Payroll Reports** - Payroll summary, staff breakdown, salary details

✅ **Design System:**
- Industrial-Professional aesthetic
- Material 3 theme support
- Custom color palette (Trust Blue, Success Green, Alert Red)
- Work Sans + Public Sans typography
- 12px rounded corners for modern feel
- High-contrast professional UI

✅ **Architecture:**
- Go Router for navigation
- Clean separation of concerns
- Reusable widget components
- Dummy static data (no backend required)
- Mobile-first responsive design

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── app.dart                            # Main app widget
├── theme/
│   └── industrial_theme.dart           # Color, typography, theme config
├── router/
│   └── app_router.dart                 # Go Router navigation setup
├── screens/
│   ├── face_auth_login_screen.dart    # Login with face scan UI
│   ├── attendance_gps_tracking_screen.dart
│   ├── owner_dashboard_screen.dart    # Main dashboard
│   └── salary_payroll_reports_screen.dart
└── widgets/                            # Reusable components
    ├── app_shell.dart                  # App wrapper with AppBar
    ├── industrial_card.dart            # Card component
    ├── stat_card.dart                  # Stats display card
    ├── status_chip.dart                # Status badge component
    ├── primary_action_button.dart      # Primary button
    └── section_header.dart             # Section header component
```

## Reusable Widgets

### AppShell
Main wrapper providing AppBar, bottom navigation, and consistent layout.

```dart
AppShell(
  title: 'WorkSync Pro',
  child: YourContent(),
  bottomNavigationBar: bottomNav,
  floatingActionButton: fab,
)
```

### IndustrialCard
Professional card with border and padding.

```dart
IndustrialCard(
  child: Text('Content'),
  highlighted: false,
  borderRadius: 12,
)
```

### StatCard
Display statistics with label, value, and optional icon.

```dart
StatCard(
  label: 'Hours Worked',
  value: '06:42',
  icon: Icons.schedule,
  valueColor: Colors.green,
)
```

### StatusChip
Status badge in 4 styles: success, pending, alert, neutral.

```dart
StatusChip(
  label: 'VERIFIED',
  type: StatusChipType.success,
  icon: Icons.check_circle,
)
```

### PrimaryActionButton
Action button with 4 styles: primary, secondary, tertiary, outline.

```dart
PrimaryActionButton(
  label: 'CHECK IN',
  icon: Icons.login,
  style: ActionButtonStyle.secondary,
  onPressed: () {},
)
```

### SectionHeader
Section title with optional subtitle and action.

```dart
SectionHeader(
  title: 'Quick Actions',
  subtitle: 'Common tasks',
  actionText: 'VIEW ALL',
  icon: Icons.flash_on,
)
```

## Color System

**Primary:** #00288E (Trust Blue)
**Primary Container:** #1E40AF
**Secondary:** #006D30 (Success Green)
**Secondary Container:** #92F5A4
**Tertiary:** #700006 (Alert Red)
**Error:** #BA1A1A
**Background:** #F8F9FF
**Surface:** #F8F9FF
**On Surface:** #121C2A (Text)

## Typography

- **Headlines:** Work Sans (700 weight)
- **Body:** Public Sans (400 weight)
- **Labels:** Atkinson Hyperlegible Next (700 weight)
- **Data:** Public Sans (600 weight)

## Navigation Routes

- `/login` - Face Authentication Login (Initial)
- `/dashboard` - Owner Dashboard
- `/attendance` - Attendance GPS Tracking
- `/salary` - Salary Payroll Reports

## Getting Started

### Prerequisites
- Flutter 3.12+
- Dart 3.12+

### Installation

1. **Get dependencies:**
```bash
flutter pub get
```

2. **Run the app:**
```bash
flutter run
```

3. **Build release APK:**
```bash
flutter build apk --release
```

## Screen Details

### 1. Face Auth Login Screen
- Animated circular face frame with scanning effect
- Pulsing border animation
- Scan line animation across frame
- Corner brackets for professional look
- "Retry Scan" and "Enter PIN" buttons
- Status indicator (Scanning...)
- Footer with language and support options

### 2. Attendance GPS Tracking Screen
- Live digital clock display
- Map placeholder with GPS pulse animation
- Location verification card
- Check-in/Check-out buttons
- Shift summary with hours worked and overtime
- Bottom navigation highlighting Attendance
- Responsive layout

### 3. Owner Dashboard Screen
- Welcome section with date
- Today's Summary card (Present/Leave/Late stats)
- Productivity progress bar (82%)
- Quick Actions grid (4 buttons)
- Recent Activity list with avatars
- Floating Action Button for quick punch
- Bottom navigation highlighting Home

### 4. Salary Payroll Reports Screen
- Payroll header with month selector dropdown
- Total Salary Payout card (₹12,45,800 for 142 employees)
- Stats cards: Overtime (842 Hrs) and Deductions (₹42,300)
- Export PDF and Share buttons
- Staff Breakdown list with employee details
- Status chips (Paid/Pending)
- Bottom navigation highlighting Salary

## Data Model

All screens use **static dummy data** for demonstration:
- Employee names, IDs, avatars
- Attendance times and statuses
- Salary information
- Location data
- Shift summary data

## Animations

- **Scanning Effect:** Scan line animation on Face Auth screen
- **Pulsing Ring:** Circular pulse animation on scanner frame
- **GPS Pulse:** Location indicator pulse on map
- **Progress Bar:** Smooth animation on loading
- **Button Press:** Scale animation on button interactions
- **List Animations:** Fade and slide effects

## Responsive Design

- Mobile-first approach
- Adapts to portrait and landscape
- Touch-friendly 48px minimum target size
- Flexible layouts with proper spacing
- Safe area handling

## Dependencies

```yaml
flutter: sdk
go_router: ^13.0.0          # Navigation
google_fonts: ^6.2.0        # Typography
cupertino_icons: ^1.0.8     # iOS icons
```

## Future Enhancements

- Firebase authentication for real face scanning
- Backend API integration
- Real GPS location tracking
- SQLite local database
- Offline mode support
- Real-time notifications
- Dark mode support
- Multi-language support
- Camera integration
- Export functionality

## Design System Reference

The app follows the exact Industrial-Professional design system from `assets/stitch_new_project/industrial_professional/DESIGN.md`:

- **Brand Personality:** Reliability, precision, accessibility
- **Emotional Response:** "Trust through clarity"
- **Layout:** 12-column desktop grid, fluid mobile grid
- **Touch Targets:** 48px minimum height
- **Spacing:** 8px modular scale
- **Elevation:** Tonal layers with low-contrast outlines (no shadows)
- **Shapes:** 8px rounded corners with pill-shaped chips

## Testing

Run the app in debug mode to test all screens:

```bash
flutter run -d <device_id>
```

Navigate between screens using the bottom navigation bar on each screen.

## Code Quality

- Clean code architecture
- Proper separation of concerns
- Reusable widget components
- Consistent naming conventions
- Type-safe Dart code
- Material 3 best practices

## Notes

- All data is static and for demonstration purposes
- No backend or Firebase configured yet
- Face authentication is UI only (no real biometric processing)
- GPS tracking is simulated with placeholder location
- Ready for backend integration

---

**Version:** 1.2.0
**Company:** DhinaDTS IT Solutions and Support (OPC) Private Limited.
**Built with:** Flutter + Material 3 + Go Router
