<?php
// Block HTML warnings and start buffer
error_reporting(0); 
ini_set('display_errors', 0);
ob_start(); 

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

// Handle preflight request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit;
}

include 'db_connect.php';

$patient_id = $_GET['patient_id'] ?? '';

if (empty($patient_id)) {
    ob_clean();
    echo json_encode([]); 
    exit;
}

// SENIOR DEV FIX 1: Added `appointment_id` to the SELECT statement
// SENIOR DEV FIX 2: Upgraded to a highly secure Prepared Statement (?)
$stmt = $conn->prepare("
    SELECT appointment_id, service, appointment_date, appointment_time, status 
    FROM appointments 
    WHERE patient_id = ? 
    ORDER BY appointment_date DESC
");

// Bind the patient_id as an integer ("i") to strictly block SQL injection
$stmt->bind_param("i", $patient_id);
$stmt->execute();
$result = $stmt->get_result();

$appointments = [];
while($row = $result->fetch_assoc()) {
    $appointments[] = $row;
}

ob_clean();
echo json_encode($appointments);

$stmt->close();
$conn->close();
?>