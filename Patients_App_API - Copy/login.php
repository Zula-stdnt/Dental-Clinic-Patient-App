<?php
error_reporting(0); 
ini_set('display_errors', 0);
ob_start(); 

date_default_timezone_set('Asia/Manila'); 

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, x-api-key");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit; }

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = isset($_POST['email']) ? trim($_POST['email']) : '';
    $password = isset($_POST['password']) ? $_POST['password'] : '';
    $captcha_answer = $_POST['captcha_answer'] ?? '';
    $captcha_hash = $_POST['captcha_hash'] ?? '';

    if (empty($email) || empty($password) || empty($captcha_answer) || empty($captcha_hash)) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Please complete all fields and the CAPTCHA."]); exit;
    }
    
    $secret_key = "YOUR_SECRET_SALT_HERE";
    if (md5($captcha_answer . $secret_key) !== $captcha_hash) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Invalid CAPTCHA."]); exit;
    }

    $stmt = $conn->prepare("SELECT * FROM patients WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        if ($row['locked_until'] !== null) {
            $locked_time = strtotime($row['locked_until']);
            if (time() < $locked_time) {
                $minutes_left = ceil(($locked_time - time()) / 60);
                ob_clean(); echo json_encode(["status" => "error", "message" => "Too many failed attempts. Try again in $minutes_left mins."]); exit;
            }
        }

        if (password_verify($password, $row['password'])) {
            $reset_stmt = $conn->prepare("UPDATE patients SET failed_attempts = 0, locked_until = NULL WHERE email = ?");
            $reset_stmt->bind_param("s", $email);
            $reset_stmt->execute();

            // NEW: Instantly return user data (NO OTP!)
            ob_clean(); echo json_encode([
                "status" => "success",
                "message" => "Login successful",
                "user" => [
                    "id" => $row['patient_id'],
                    "first_name" => $row['first_name'],
                    "middle_name" => $row['middle_name'],
                    "last_name" => $row['last_name'],
                    "email" => $row['email'],
                    "phone_number" => $row['phone_number'],
                    "dob" => $row['dob']
                ]
            ]);
        } else {
            $new_fails = $row['failed_attempts'] + 1;
            if ($new_fails >= 5) {
                $lock_stmt = $conn->prepare("UPDATE patients SET failed_attempts = ?, locked_until = DATE_ADD(NOW(), INTERVAL 10 MINUTE) WHERE email = ?");
                $lock_stmt->bind_param("is", $new_fails, $email);
                $lock_stmt->execute();
                ob_clean(); echo json_encode(["status" => "error", "message" => "Too many failed login attempts."]);
            } else {
                $inc_stmt = $conn->prepare("UPDATE patients SET failed_attempts = ? WHERE email = ?");
                $inc_stmt->bind_param("is", $new_fails, $email);
                $inc_stmt->execute();
                ob_clean(); echo json_encode(["status" => "error", "message" => "Incorrect password. You have " . (5 - $new_fails) . " attempts left."]);
            }
        }
    } else {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Invalid credentials"]);
    }
}
?>