<?php
// Bulletproof CORS & Preflight handling
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

header("Content-Type: application/json");
$conn = new mysqli("localhost", "root", "", "dental_clinic");

// Catch Data: Works for both standard Form-Data and Flutter's Raw JSON
$appointment_id = $_POST['appointment_id'] ?? null;
$action = $_POST['action'] ?? null;

if (!$appointment_id) {
    $raw = file_get_contents('php://input');
    $json = json_decode($raw, true);
    if(isset($json['appointment_id'])) {
        $appointment_id = $json['appointment_id'];
        $action = $json['action'];
    }
}

// Error handling if data is missing
if (!$appointment_id || !$action) {
    echo json_encode(["success" => false, "message" => "ERROR: Missing data. Cannot update database."]);
    exit;
}

// Strictly force the ID to an integer
$app_id_int = intval($appointment_id);

// 1. UPDATE THE APPOINTMENTS TABLE
if ($action === 'approved') {
    $stmt = $conn->prepare("UPDATE appointments SET status = 'approved', approved_at = NOW() WHERE appointment_id = ?");
} else {
    $stmt = $conn->prepare("UPDATE appointments SET status = 'declined', declined_at = NOW() WHERE appointment_id = ?");
}
$stmt->bind_param("i", $app_id_int);
$stmt->execute();

// Verify that the row actually changed in the appointments table
if ($stmt->affected_rows > 0) {
    
    // 2. SENIOR DEV FIX: SYNC THE SMS NOTIFICATIONS TABLE
    // This ensures the admin's SMS log matches the appointment AND triggers the unread badge
    $sms_stmt = $conn->prepare("UPDATE sms_notifications SET status = ?, is_read = 0 WHERE appointment_id = ?");
    $sms_stmt->bind_param("si", $action, $app_id_int);
    $sms_stmt->execute();
    $sms_stmt->close();

    echo json_encode(["success" => true, "message" => "SUCCESS: Appointment $action!"]);
} else {
    echo json_encode(["success" => false, "message" => "ERROR: 0 rows updated. ID $app_id_int not found or status already changed."]);
}

$stmt->close();
$conn->close();
?>