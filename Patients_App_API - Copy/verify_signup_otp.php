<?php
error_reporting(0); 
ini_set('display_errors', 0);
ob_start(); 

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = $_POST['email'] ?? '';
    // NEW: Expecting single code
    $entered_otp = $_POST['otp_code'] ?? ''; 
    
    $first_name = $_POST['first_name'] ?? '';
    $middle_name = $_POST['middle_name'] ?? '';
    $last_name = $_POST['last_name'] ?? '';
    $phone_number = $_POST['phone_number'] ?? '';
    $dob = $_POST['dob'] ?? NULL;
    $password = $_POST['password'] ?? '';
    $security_question = $_POST['security_question'] ?? '';
    $security_answer = $_POST['security_answer'] ?? '';

    if (empty($email) || empty($entered_otp)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Verification code is required."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT * FROM temporary_otp WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();

        if (time() > strtotime($row['otp_expires_at'])) {
            ob_clean();
            echo json_encode(["status" => "error", "message" => "OTP has expired. Please restart registration."]);
            exit;
        }

        // ==========================================
        // NEW: SINGLE VERIFICATION
        // ==========================================
        if ($entered_otp === $row['phone_otp']) {
            
            $hashed_password = password_hash($password, PASSWORD_DEFAULT);
            $normalized_answer = strtolower(trim($security_answer));
            $hashed_security_answer = password_hash($normalized_answer, PASSWORD_DEFAULT);

            $insert_stmt = $conn->prepare("INSERT INTO patients (first_name, middle_name, last_name, phone_number, dob, email, password, security_question, security_answer) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
            $dob_val = ($dob === "" || $dob === "Date of Birth") ? NULL : $dob;
            $insert_stmt->bind_param("sssssssss", $first_name, $middle_name, $last_name, $phone_number, $dob_val, $email, $hashed_password, $security_question, $hashed_security_answer);
            
            if ($insert_stmt->execute()) {
                $del_stmt = $conn->prepare("DELETE FROM temporary_otp WHERE email = ?");
                $del_stmt->bind_param("s", $email);
                $del_stmt->execute();

                ob_clean();
                echo json_encode(["status" => "success", "message" => "Account successfully created!"]);
            } else {
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Database error during account creation."]);
            }
        } else {
            $new_attempts = $row['otp_attempts'] + 1;
            if ($new_attempts >= 3) {
                $del_stmt = $conn->prepare("DELETE FROM temporary_otp WHERE email = ?");
                $del_stmt->bind_param("s", $email);
                $del_stmt->execute();
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Too many incorrect attempts. Please restart registration."]);
            } else {
                $inc_stmt = $conn->prepare("UPDATE temporary_otp SET otp_attempts = ? WHERE email = ?");
                $inc_stmt->bind_param("is", $new_attempts, $email);
                $inc_stmt->execute();
                ob_clean();
                echo json_encode(["status" => "error", "message" => "Incorrect Verification Code."]);
            }
        }
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Session expired or invalid."]);
    }
}
?>