<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header("Content-Type: application/json");
$conn = new mysqli("localhost", "root", "", "dental_clinic");

$patient_id = $_POST['patient_id'] ?? null;
$service = $_POST['service'] ?? null;
$date = $_POST['appointment_date'] ?? null;
$time = $_POST['appointment_time'] ?? null;

if (!$patient_id) {
    $raw = file_get_contents('php://input');
    $json = json_decode($raw, true);
    if(isset($json['patient_id'])) {
        $patient_id = $json['patient_id'];
        $service = $json['service'];
        $date = $json['appointment_date'];
        $time = $json['appointment_time'];
    }
}

if (!$patient_id || !$service || !$date || !$time) {
    echo json_encode(["success" => false, "message" => "Missing required booking details."]);
    exit;
}

$patient_id = intval($patient_id);

// 🚨 SENIOR DEV FIX: The Firewall Check!
// Check if the patient is currently serving a 30-day penalty
$blockStmt = $conn->prepare("SELECT blocked_until, CONCAT(first_name, ' ', last_name) AS full_name FROM patients WHERE patient_id = ?");
$blockStmt->bind_param("i", $patient_id);
$blockStmt->execute();
$patient_res = $blockStmt->get_result()->fetch_assoc();
$blockStmt->close();

if (!$patient_res) {
    echo json_encode(["success" => false, "message" => "Patient record not found."]);
    exit;
}

$patient_name = $patient_res['full_name'];

// If the blocked_until date exists AND is in the future, Reject the booking!
if (!empty($patient_res['blocked_until'])) {
    $blocked_date = new DateTime($patient_res['blocked_until']);
    $now = new DateTime();
    
    if ($now < $blocked_date) {
        $unlock_date = $blocked_date->format('M d, Y');
        echo json_encode(["success" => false, "message" => "Account restricted due to multiple No-Shows. You can book again on $unlock_date."]);
        exit;
    }
}

// If they passed the firewall (or their 30 days are up), allow the booking:
$status = 'pending';
$stmt = $conn->prepare("INSERT INTO appointments (patient_id, service, appointment_date, appointment_time, status, created_at) VALUES (?, ?, ?, ?, ?, NOW())");
$stmt->bind_param("issss", $patient_id, $service, $date, $time, $status);

if ($stmt->execute()) {
    $new_appointment_id = $stmt->insert_id; 

    // Trigger Admin Notification
    $message = "New appointment request for $service on " . date("M d", strtotime($date)) . " at " . date("h:i A", strtotime($time)) . ".";
    $sender = "Patient";
    
    $sms_stmt = $conn->prepare("INSERT INTO sms_notifications (appointment_id, patient_name, service, status, message, is_read, sender_type, sent_at) VALUES (?, ?, ?, ?, ?, 0, ?, NOW())");
    $sms_stmt->bind_param("isssss", $new_appointment_id, $patient_name, $service, $status, $message, $sender);
    $sms_stmt->execute();
    $sms_stmt->close();

    echo json_encode(["success" => true, "message" => "Appointment successfully booked!"]);
} else {
    echo json_encode(["success" => false, "message" => "Failed to book appointment. Database error."]);
}

$stmt->close();
$conn->close();
?>