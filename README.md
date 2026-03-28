# RevolutionUC 2026 — Cortisol Tracker

iOS app that uses the Presage SmartSpectra SDK to track cortisol/stress levels via camera-based PPG.

## Stack
- **Frontend**: SwiftUI (iOS native)
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **SDK**: Presage SmartSpectra Swift SDK

## Core Features
- Track cortisol/stress levels using Presage SDK (camera-based vitals: heart rate, HRV, SpO2, respiratory rate, stress)
- Calendar view of historical cortisol data
- Log lifestyle inputs: sleep, diet, stressful activities
- Friends feature — see friends' cortisol levels
- AI-generated tips based on schedule to lower cortisol

## Presage SDK
- Docs: https://docs.physiology.presagetech.com/
- Swift SDK: https://docs.physiology.presagetech.com/swift/documentation/smartspectraswiftsdk/
- Measures: heart rate, HRV, SpO2, respiratory rate, stress level via camera PPG
- Requires camera permission

## Project Structure
```
CortisolTracker/
  Models/        # Data models (User, CortisolReading, Activity, Friend)
  Views/         # SwiftUI views (Calendar, Dashboard, Friends, Tips)
  ViewModels/    # View models
  Services/      # Firebase, Presage SDK, AI tips service
```
