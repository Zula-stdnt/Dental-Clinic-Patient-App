<?php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include 'db_connect.php';

$patient_id = isset($_GET['patient_id']) ? intval($_GET['patient_id']) : 0;

$sql = "SELECT COUNT(*) as unread 
        FROM sms_notifications s
        JOIN appointments a ON s.appointment_id = a.appointment_id
        WHERE a.patient_id = $patient_id AND s.is_read = 0 AND s.sender_type = 'admin'";

$result = $conn->query($sql);
$count = 0;

if ($result && $row = $result->fetch_assoc()) {
    $count = intval($row['unread']);
}

echo json_encode(["unread" => $count]);
?>