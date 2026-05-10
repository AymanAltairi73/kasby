# Kasby Admin App - Technical Specification & Prompt

This document provides a comprehensive guide for building the **Kasby Admin App**. It contains the visual identity, functional requirements, and design guidelines derived from the main Kasby investor application to ensure a seamless and professional administrative experience.

---

## 🎨 Visual Identity & Design System

The Admin App **must** strictly adhere to the following design tokens to maintain brand consistency:

### 1. Color Palette (Dark Theme)
- **Primary Color:** `#C9A24D` (Dark Gold)
- **Primary Gradient:** `#C9A24D` to `#E5C173` (Top-Left to Bottom-Right)
- **Background:** `#0E0E11` (Dark Navy/Black)
- **Surface/Card Color:** `#1A1A1F` (Slightly lighter than background)
- **Success Color:** `#4CAF50` (Soft Green)
- **Error Color:** `#CF6679`
- **Text (Primary):** `#FFFFFF` (White)
- **Text (Body):** `#E0E0E0`
- **Text (Secondary/Hint):** `#A0A0A0`

### 2. Typography
- **Primary Font Family:** `IBMPlexSansArabic`
- **Headings:** Bold, White, sizes: 32 (Large), 28 (Medium), 24 (Small).
- **Body Text:** Regular/Medium, `0xFFE0E0E0`, sizes: 16 (Large), 14 (Medium).

### 3. UI Characteristics
- **Theme:** Dark Mode by default.
- **Corner Radius:** `16px` for cards, buttons, and text fields.
- **Animations:** Subtle fade-ins and slide-ups (using `flutter_animate`).
- **Feedback:** Haptic feedback on button presses (light impact).

---

## 📱 Functional Requirements

### 1. Authentication & Security
- **Admin Login:** Secure login with username/password.
- **OTP Protection:** Mandatory One-Time Password (OTP) for sensitive actions or login.
- **Password Recovery:** "Forgot Password" flow.

### 2. Admin Dashboard (Main Overview)
- **Key Metrics:**
  - Total Users Count.
  - Total Investments Volume.
  - Total Profits Paid.
  - Daily Transactions Count.
- **Visuals:** Mini charts and graphs showing growth/trends.

### 3. User Management
- **User List:** Searchable and filterable list of all registered users.
- **User Detailed View:**
  - View Wallet Balance.
  - Active/Past Investments.
  - Transaction History.
- **Administrative Actions:**
  - Add/Subtract balance (with audit log).
  - Activate/Suspend/Block user accounts.

### 4. Investment Management
- **Investment Plans:**
  - Create new plans or edit existing ones.
  - Modify profit percentages and durations.
  - Enable/Disable specific plans.
- **User Investments:** Monitor active and completed investment cycles.

### 5. Agent (Proxy) Management
- **List Agents:** View all registered agents/proxies.
- **Agent Actions:** Add new agent, edit details, or change status (Active/Inactive).

### 6. Transactions (Deposits & Withdrawals)
- **Approval Workflow:**
  - Review pending deposit requests (Approve/Reject with reasons).
  - Review pending withdrawal requests (Approve/Reject).
- **History:** Searchable log of all financial operations.

### 7. Gamification & Rewards
- **Spin the Wheel:** Configure prizes, probabilities, and active status.
- **Daily Check-in:** Set reward amounts for consecutive logins.
- **Points System:** Control points-to-cash conversion rates.

### 8. Subscriptions
- **Plan Management:** Manage subscription tiers for users.
- **User Status:** View and manually override user subscription status.

### 9. Notifications & Settings
- **Broadcasts:** Send push notifications (General or targeted to specific users).
- **App Config:** Update app-wide settings (Terms of Service, Help text, Maintenance mode).

---

## 🛠 Technical Guidelines

### Architecture
- **Framework:** Flutter.
- **Structure:** Feature-based folder structure (e.g., `lib/features/dashboard`, `lib/features/users`).
- **State Management:** Use consistent patterns (e.g., Bloc/Cubit or Provider).

### Common UI Components
- **Buttons (`KasbyButton`):** Should have a gold gradient or solid gold background with rounded corners (16px).
- **Inputs (`KasbyTextField`):** Filled style (`#1A1A1F`), no border except when focused (`#C9A24D`).
- **Cards (`KasbyCard`):** Surface color (`#1A1A1F`), elevation 0, 16px radius.

---

## 🚀 AI Prompt for Building the App

> "Act as a Senior Flutter Developer. Build a professional Admin App for the 'Kasby' fintech platform using the following specifications. Use a feature-based architecture. Implement a sleek Dark Theme using hex codes: Background `#0E0E11`, Primary Gold `#C9A24D`, Surface `#1A1A1F`. Use `IBMPlexSansArabic` for all text. The app should include modules for Dashboard, User Management, Investment Control, Transaction Approvals (Deposits/Withdrawals), and Gamification settings. Ensure all components use a 16px corner radius and include subtle micro-animations for a premium feel."
