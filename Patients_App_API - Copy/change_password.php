<?php
error_reporting(0);
ini_set('display_errors', 0);
ob_start();
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $patient_id = $_POST['patient_id'] ?? '';
    $current_password = $_POST['current_password'] ?? '';
    $new_password = $_POST['new_password'] ?? '';

    if (empty($patient_id) || empty($current_password) || empty($new_password)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "All fields are required."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT password FROM patients WHERE patient_id = ?");
    $stmt->bind_param("s", $patient_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();

        // Verify the current password
        if (password_verify($current_password, $row['password'])) {
            $new_hashed = password_hash($new_password, PASSWORD_DEFAULT);
            
            $update_sql = "UPDATE patients SET password = ? WHERE patient_id = ?";
            $upd_stmt = $conn->prepare($update_sql);
            $upd_stmt->bind_param("ss", $new_hashed, $patient_id);
            
            if ($upd_stmt->execute()) {
                ob_clean();
                echo json_encode(["status" => "success", "message" => "Password securely updated!"]);
            } else {
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Database error."]);
            }
        } else {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Incorrect Current Password."]);
        }
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "User not found."]);
    }
}
?>