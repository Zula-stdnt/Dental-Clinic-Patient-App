<?php
error_reporting(0); 
ini_set('display_errors', 0);
ob_start(); 

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $patient_id = $_POST['patient_id'] ?? '';
    $service = $_POST['service'] ?? '';
    $date = $_POST['date'] ?? '';
    $start_time = $_POST['time'] ?? '';
    $end_time = $_POST['end_time'] ?? ''; // NEW: Capture end time

    if (empty($patient_id) || empty($service) || empty($date) || empty($start_time) || empty($end_time)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "All appointment details (including duration) are required"]);
        exit;
    }

    $patient_id = $conn->real_escape_string($patient_id);
    $service = $conn->real_escape_string($service);
    $date = $conn->real_escape_string($date);
    $start_time = $conn->real_escape_string($start_time);
    $end_time = $conn->real_escape_string($end_time);

    // 1. The Penalty Firewall
    $blockStmt = $conn->prepare("SELECT blocked_until, CONCAT(first_name, ' ', last_name) AS full_name FROM patients WHERE patient_id = ?");
    $blockStmt->bind_param("s", $patient_id);
    $blockStmt->execute();
    $patient_res = $blockStmt->get_result()->fetch_assoc();
    $blockStmt->close();

    if ($patient_res && !empty($patient_res['blocked_until'])) {
        $blocked_date = new DateTime($patient_res['blocked_until']);
        $now = new DateTime();
        
        if ($now < $blocked_date) {
            $unlock_date = $blocked_date->format('M d, Y');
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Account restricted due to multiple No-Shows. You can book again on $unlock_date."]);
            exit;
        }
    }

    // 2. The Overlap Firewall (Crucial for Dynamic Slots)
    // Check if ANY active appointment on this date overlaps with our requested start and end time
    $overlapStmt = $conn->prepare("
        SELECT appointment_id FROM appointments 
        WHERE appointment_date = ? 
        AND status IN ('pending', 'approved', 'rescheduled')
        AND (appointment_time < ? AND end_time > ?)
    ");
    $overlapStmt->bind_param("sss", $date, $end_time, $start_time);
    $overlapStmt->execute();
    $overlapResult = $overlapStmt->get_result();

    if ($overlapResult->num_rows > 0) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "This time slot overlaps with another scheduled appointment. Please select a different time."]);
        exit;
    }
    $overlapStmt->close();

    // 3. Insert the Appointment
    $patient_name = $patient_res ? $patient_res['full_name'] : "Unknown Patient";

    $sql = "INSERT INTO appointments (patient_id, service, appointment_date, appointment_time, end_time, status, created_at) 
            VALUES ('$patient_id', '$service', '$date', '$start_time', '$end_time', 'pending', NOW())";
    
    if ($conn->query($sql) === TRUE) {
        $new_appointment_id = $conn->insert_id;

        $message = "New appointment request for $service on " . date("M d", strtotime($date)) . " at " . date("h:i A", strtotime($start_time)) . ".";
        
        $sms_stmt = $conn->prepare("INSERT INTO sms_notifications (appointment_id, patient_name, service, status, message, is_read, sender_type, sent_at) VALUES (?, ?, ?, 'pending', ?, 0, 'Patient', NOW())");
        $sms_stmt->bind_param("isss", $new_appointment_id, $patient_name, $service, $message);
        $sms_stmt->execute();
        $sms_stmt->close();

        ob_clean();
        echo json_encode(["status" => "success", "message" => "Appointment successfully booked!"]);
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Failed to book appointment. Database error."]);
    }
}
?>