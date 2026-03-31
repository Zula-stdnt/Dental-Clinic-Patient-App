# 🦷 Agusan Local Dental Clinic - Patient Mobile App

The **Patient Mobile App** is a high-performance, cross-platform solution developed with **Flutter**. It serves as the primary gateway for patients of the Agusan Local Dental Clinic to manage their oral health journeys. By digitizing the booking process, the app reduces clinic wait times and automates patient-doctor communication.

---

## 📱 Features Breakdown

### 🔐 1. Smart Onboarding & Security
*   **User Authentication:** A secure registration and login system that bridges patient data directly to the central MySQL database.
*   **Profile Management:** Patients can maintain up-to-date contact information, ensuring they never miss a critical SMS alert.
*   **Persistent Login:** Optimized session management so patients can check their appointment status instantly without re-logging.

<p align="center">
  <img src="https://github.com/user-attachments/assets/17675d6b-9b1e-416d-8fde-6053dbeaeb67" width="30%" alt="Sign Up Screen" />
  <img src="https://github.com/user-attachments/assets/c2cf8d73-8725-4f41-8874-bee579e9626a" width="30%" alt="Login Screen" />
  <img src="https://github.com/user-attachments/assets/80f68744-e7d4-4b9f-9911-23ed2a0f0968" width="30%" alt="Profile Screen" />
</p>

---
### 📅 2. Intelligent Appointment Scheduling
*   **Service Selection:** A clean, searchable catalog of dental treatments and procedures.
*   **Real-time Availability Calendar:** An interactive booking system where patients select their preferred dates.
*   **Admin Sync (Blocked Dates):** The app intelligently hides and disables any dates or time slots "blocked" by the dentist (for emergencies or holidays) on the Admin Web Panel, eliminating scheduling conflicts.

<p align="center">
  <img src="https://github.com/user-attachments/assets/bd68c78e-9a03-42a8-85c5-9dfc34538af6" width="45%" alt="Dashboard Screen" />
  <img src="https://github.com/user-attachments/assets/f221859d-a413-4ac6-aafd-4ee4e43f3b65" width="45%" alt="Booking Calendar Screen" />
</p>

---
### 🔄 3. Dynamic Appointment Lifecycle
*   **Live Status Tracking:** Real-time visibility into the status of every request: `Pending`, `Approved`, `Rescheduled`, or `Completed`.
*   **Interactive Rescheduling:** A unique two-way workflow. If the dentist proposes a new time, the patient receives an in-app prompt to **Accept** or **Decline**, which instantly updates the clinic's dashboard.
*   **Treatment History:** A digital record of all past visits, services received, and appointment outcomes.

<p align="center">
  <img src="https://github.com/user-attachments/assets/0ff99576-5040-41a4-90c0-a47b2095d41d" width="250" alt="Appointments Screen" />
</p>

---
### 🚫 4. Automated Accountability (No Show Policy)
*   **System-Enforced Ban:** To protect the clinic's schedule, the app tracks "No Show" records. If a patient reaches **two (2) No Show statuses**, the system automatically imposes a **30-day booking ban**.
*   **Policy Transparency:** The app clearly displays the patient's current eligibility status (Active or Banned) to ensure compliance with clinic rules.

### 💬 5. SMS Integration (via TextBee)
This app leverages the **TextBee Gateway** to provide high-speed, cost-effective notifications.
*   **Automated Alerts:** Patients receive SMS confirmations for bookings, approvals, and reminders.
*   **Reschedule Notifications:** Immediate SMS triggers when the dentist suggests a new appointment time.

<p align="center">
  <img src="https://github.com/user-attachments/assets/b7cc1703-67e2-44dc-b8d3-5ee66a258dfc" width="250" alt="SMS Notifications Log" />
</p>
---

## 🛠️ Technical Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Backend:** PHP / MySQL (REST API)
*   **SMS Gateway:** [TextBee.dev](https://textbee.dev/) (Android-to-SMS Bridge)
*   **Architecture:** Modular and Clean Code approach for scalability.

---

## 🚀 Installation & Setup

### Prerequisites
*   Flutter SDK (Stable Channel)
*   Android Studio / VS Code
*   A running instance of the **Agusan Dental Admin Backend**

### Step-by-Step
1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/yourusername/agusan-patient-app.git
    ```
2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Environment Configuration:**
    Navigate to `lib/config/constants.dart` (or your config file) and update the following:
    *   `BASE_URL`: Your PHP API endpoint.
    *   `TEXTBEE_API_KEY`: Your unique API key from TextBee.
    *   `DEVICE_ID`: Your registered Android gateway ID.

4.  **Run the App:**
    ```bash
    flutter run
    ```

---

## 🎨 User Interface
The app follows a professional **Dental Blue and Mint Green** color palette, emphasizing a clean, clinical, yet welcoming aesthetic. All interactions include **confirmation modals** to prevent accidental bookings or cancellations.

---

## 👨‍💻 Developer
**Villaluna, Zuriel Anthony L.**  
*Lead Developer - Agusan Local Dental Clinic Management System*
