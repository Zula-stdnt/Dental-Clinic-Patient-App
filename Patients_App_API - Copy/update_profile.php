<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $patient_id = $_POST['patient_id'] ?? '';
    $first_name = $_POST['first_name'] ?? '';
    $middle_name = $_POST['middle_name'] ?? '';
    $last_name = $_POST['last_name'] ?? '';
    $new_email = $_POST['email'] ?? '';
    $new_phone = $_POST['phone_number'] ?? '';
    $dob = $_POST['dob'] ?? '';
    
    // NEW: Expecting single code
    $entered_otp = $_POST['otp_code'] ?? '';
    
    if (empty($patient_id) || empty($first_name) || empty($last_name) || empty($new_email) || empty($new_phone)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Critical fields cannot be empty."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT email, phone_number, phone_otp, otp_expires_at, otp_attempts FROM patients WHERE patient_id = ?");
    $stmt->bind_param("s", $patient_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "User not found."]);
        exit;
    }

    $row = $result->fetch_assoc();
    $requires_otp = ($new_email !== $row['email'] || $new_phone !== $row['phone_number']);

    if ($requires_otp) {
        if (empty($entered_otp)) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Verification code is required to change Email or Phone Number."]);
            exit;
        }

        if (time() > strtotime($row['otp_expires_at'])) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "OTP has expired."]);
            exit;
        }

        // NEW: Single Check
        if ($entered_otp !== $row['phone_otp']) {
            $new_attempts = $row['otp_attempts'] + 1;
            $inc_stmt = $conn->prepare("UPDATE patients SET otp_attempts = ? WHERE patient_id = ?");
            $inc_stmt->bind_param("is", $new_attempts, $patient_id);
            $inc_stmt->execute();
            ob_clean();
            echo json_encode(["status" => "error", "message" => "Incorrect OTP verification. Try again."]);
            exit;
        }
    }

    $patient_id = $conn->real_escape_string($patient_id);
    $first_name = $conn->real_escape_string($first_name);
    $middle_name = $conn->real_escape_string($middle_name);
    $last_name = $conn->real_escape_string($last_name);
    $new_email = $conn->real_escape_string($new_email);
    $new_phone = $conn->real_escape_string($new_phone);
    $dob = $conn->real_escape_string($dob);

    $sql = "UPDATE patients 
            SET first_name = '$first_name', middle_name = '$middle_name', last_name = '$last_name', 
                email = '$new_email', phone_number = '$new_phone', dob = " . ($dob ? "'$dob'" : "NULL") . ",
                phone_otp = NULL, email_otp = NULL, otp_expires_at = NULL, otp_attempts = 0
            WHERE patient_id = '$patient_id'";

    if ($conn->query($sql) === TRUE) {
        ob_clean();
        echo json_encode(["status" => "success", "message" => "Profile updated successfully!"]);
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Database error: " . $conn->error]);
    }
}
?>