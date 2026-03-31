<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = $_POST['email'] ?? '';

    if (empty($email)) {
        echo json_encode(["status" => "error", "message" => "Please enter an email address."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT security_question FROM patients WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        // Return success and the specific question
        echo json_encode([
            "status" => "success", 
            "security_question" => $row['security_question']
        ]);
    } else {
        // Option A: User-friendly error
        echo json_encode(["status" => "error", "message" => "Email not found. Please check your spelling."]);
    }
}
?>