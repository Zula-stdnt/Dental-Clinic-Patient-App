<?php
error_reporting(0);
ini_set('display_errors', 0);
ob_start();

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include 'db_connect.php';

$date = $_GET['date'] ?? '';

if (empty($date)) {
    ob_clean();
    echo json_encode([]);
    exit;
}

$booked_ranges = [];

// 1. Fetch Patient Appointments
$stmt1 = $conn->prepare("
    SELECT appointment_time AS start_time, end_time 
    FROM appointments 
    WHERE appointment_date = ? 
    AND status IN ('pending', 'approved', 'rescheduled')
");
$stmt1->bind_param("s", $date);
$stmt1->execute();
$result1 = $stmt1->get_result();

while ($row = $result1->fetch_assoc()) {
    $booked_ranges[] = [
        "start" => $row['start_time'],
        "end" => $row['end_time'],
        "type" => "appointment",
        "reason" => "Booked" // Generic reason for privacy
    ];
}
$stmt1->close();

// 2. Fetch Admin Blocked Times
$stmt2 = $conn->prepare("
    SELECT start_time, end_time, reason 
    FROM disabled_times 
    WHERE block_date = ?
");
$stmt2->bind_param("s", $date);
$stmt2->execute();
$result2 = $stmt2->get_result();

while ($row = $result2->fetch_assoc()) {
    $booked_ranges[] = [
        "start" => $row['start_time'],
        "end" => $row['end_time'],
        "type" => "admin_block",
        "reason" => $row['reason'] ?? "Clinic Blocked" // Use DB reason, fallback if empty
    ];
}
$stmt2->close();

ob_clean();
echo json_encode($booked_ranges);
$conn->close();
?>