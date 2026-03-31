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
    $entered_otp = $_POST['otp_code'] ?? '';

    if (empty($patient_id) || empty($entered_otp)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Missing verification data."]);
        exit;
    }

    // FIXED: Using a safe SELECT * to avoid missing column crashes
    $stmt = $conn->prepare("SELECT * FROM patients WHERE patient_id = ?");
    $stmt->bind_param("s", $patient_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();

        if (time() > strtotime($row['otp_expires_at'])) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "OTP has expired. Please log in again."]);
            exit;
        }

        // Since login uses the same code for both, checking phone_otp is sufficient
        if ($entered_otp === $row['phone_otp']) {
            // SUCCESS! Wipe the temporary codes to secure the account
            $wipe_stmt = $conn->prepare("UPDATE patients SET phone_otp = NULL, email_otp = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE patient_id = ?");
            $wipe_stmt->bind_param("s", $patient_id);
            $wipe_stmt->execute();

            ob_clean();
            echo json_encode([
                "status" => "success",
                "user" => [
                    "id" => $patient_id,
                    "first_name" => $row['first_name'],
                    "middle_name" => $row['middle_name'],
                    "last_name" => $row['last_name'],
                    "email" => $row['email'],
                    "phone_number" => $row['phone_number'],
                    "dob" => $row['dob']
                ]
            ]);
        } else {
            // FAILURE
            $new_attempts = $row['otp_attempts'] + 1;
            if ($new_attempts >= 3) {
                $wipe_stmt = $conn->prepare("UPDATE patients SET phone_otp = NULL, email_otp = NULL, otp_expires_at = NULL, otp_attempts = 0 WHERE patient_id = ?");
                $wipe_stmt->bind_param("s", $patient_id);
                $wipe_stmt->execute();
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Too many incorrect attempts. Please log in again."]);
            } else {
                $inc_stmt = $conn->prepare("UPDATE patients SET otp_attempts = ? WHERE patient_id = ?");
                $inc_stmt->bind_param("is", $new_attempts, $patient_id);
                $inc_stmt->execute();
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Incorrect OTP. Please try again."]);
            }
        }
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "User not found."]);
    }
}
?>