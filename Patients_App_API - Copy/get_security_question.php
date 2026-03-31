<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET");
header("Content-Type: application/json");

include 'db_connect.php';

$patient_id = $_GET['patient_id'] ?? '';

if (empty($patient_id)) {
    echo json_encode(["status" => "error", "message" => "Patient ID required"]);
    exit;
}

$stmt = $conn->prepare("SELECT security_question FROM patients WHERE patient_id = ?");
$stmt->bind_param("s", $patient_id);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode(["status" => "success", "security_question" => $row['security_question']]);
} else {
    echo json_encode(["status" => "error", "message" => "User not found."]);
}
?>