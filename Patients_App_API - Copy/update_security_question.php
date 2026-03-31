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
    $password = $_POST['password'] ?? '';
    $old_answer = $_POST['old_answer'] ?? '';
    $new_question = $_POST['new_question'] ?? '';
    $new_answer = $_POST['new_answer'] ?? '';

    if (empty($patient_id) || empty($password) || empty($old_answer) || empty($new_question) || empty($new_answer)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "All fields are required."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT password, security_answer FROM patients WHERE patient_id = ?");
    $stmt->bind_param("s", $patient_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();

        if (!password_verify($password, $row['password'])) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Incorrect Current Password."]);
            exit;
        }

        $normalized_old = strtolower(trim($old_answer));
        if (!password_verify($normalized_old, $row['security_answer'])) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Incorrect Current Security Answer."]);
            exit;
        }

        $normalized_new = strtolower(trim($new_answer));
        $hashed_new = password_hash($normalized_new, PASSWORD_DEFAULT);

        $update_stmt = $conn->prepare("UPDATE patients SET security_question = ?, security_answer = ? WHERE patient_id = ?");
        $update_stmt->bind_param("sss", $new_question, $hashed_new, $patient_id);
        
        if ($update_stmt->execute()) {
            ob_clean();
            echo json_encode(["status" => "success", "message" => "Security question updated securely."]);
        } else {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Database error."]);
        }
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "User not found."]);
    }
}
?>