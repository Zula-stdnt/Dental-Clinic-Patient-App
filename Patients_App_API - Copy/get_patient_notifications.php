<?php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include 'db_connect.php'; 

$patient_id = isset($_GET['patient_id']) ? intval($_GET['patient_id']) : 0;

if ($patient_id === 0) {
    echo json_encode([]);
    exit;
}

// Fetch notifications specifically for this patient
$sql = "SELECT s.message, s.sent_at, s.is_read 
        FROM sms_notifications s
        JOIN appointments a ON s.appointment_id = a.appointment_id
        WHERE a.patient_id = $patient_id AND s.sender_type = 'admin'
        ORDER BY s.sent_at DESC";

$result = $conn->query($sql);
$notifications = [];

if ($result) {
    while ($row = $result->fetch_assoc()) {
        $notifications[] = $row;
    }
}

echo json_encode($notifications);
$conn->close();
?>