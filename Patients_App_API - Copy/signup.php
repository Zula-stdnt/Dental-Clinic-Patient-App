<?php
error_reporting(0); 
ini_set('display_errors', 0);
ob_start(); 

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') { http_response_code(200); exit; }

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = trim($_POST['email'] ?? '');
    $phone_number = trim($_POST['phone_number'] ?? '');
    $password = $_POST['password'] ?? '';
    $captcha_answer = $_POST['captcha_answer'] ?? '';
    $captcha_hash = $_POST['captcha_hash'] ?? '';

    if (empty($email) || empty($phone_number) || empty($password)) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Critical fields missing."]); exit;
    }

    if (empty($captcha_answer) || empty($captcha_hash)) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Please complete the CAPTCHA verification."]); exit;
    }

    $secret_key = "YOUR_SECRET_SALT_HERE";
    if (md5($captcha_answer . $secret_key) !== $captcha_hash) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "Invalid CAPTCHA."]); exit;
    }

    $email = $conn->real_escape_string($email);
    $phone_number = $conn->real_escape_string($phone_number);

    $check_email = "SELECT email FROM patients WHERE email = '$email'";
    $result = $conn->query($check_email);
    if ($result->num_rows > 0) {
        ob_clean(); echo json_encode(["status" => "error", "message" => "This Email is already in use."]); exit;
    }

    $stmt = $conn->prepare("SELECT phone_number, phone_otp, otp_expires_at FROM temporary_otp WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $temp_result = $stmt->get_result();

    if ($temp_result && $temp_result->num_rows > 0) {
        $temp_row = $temp_result->fetch_assoc();
        $time_left = strtotime($temp_row['otp_expires_at']) - time();
        $seconds_since_sent = 300 - $time_left;
        
        if ($seconds_since_sent >= 0 && $seconds_since_sent < 60 && $temp_row['phone_number'] === $phone_number) {
            $response = [
                "status" => "require_otp", 
                "message" => "An OTP was just sent! Please wait 60 seconds before requesting a new one.",
                "email" => $email,
                "phone_number" => substr($phone_number, 0, 6) . '*****' . substr($phone_number, -2)
            ];
            if (!USE_LIVE_APIS) {
                $response["mock_otp"] = $temp_row['phone_otp'];
            }
            ob_clean();
            echo json_encode($response);
            exit; 
        }
    }

    // NEW: Generate ONE code
    $otp_code = sprintf("%06d", mt_rand(100000, 999999));
    $expires_at = date("Y-m-d H:i:s", strtotime("+5 minutes"));

    // Save the exact same code into both columns
    $temp_stmt = $conn->prepare("INSERT INTO temporary_otp (email, phone_number, phone_otp, email_otp, otp_expires_at, otp_attempts) VALUES (?, ?, ?, ?, ?, 0) ON DUPLICATE KEY UPDATE phone_number = ?, phone_otp = ?, email_otp = ?, otp_expires_at = ?, otp_attempts = 0");
    $temp_stmt->bind_param("sssssssss", $email, $phone_number, $otp_code, $otp_code, $expires_at, $phone_number, $otp_code, $otp_code, $expires_at);
    $temp_stmt->execute();

    if (USE_LIVE_APIS) {
        $ch_sms = curl_init();
        curl_setopt($ch_sms, CURLOPT_URL, "https://api.textbee.dev/api/v1/gateway/devices/" . TEXTBEE_DEVICE_ID . "/send-sms");
        curl_setopt($ch_sms, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch_sms, CURLOPT_POST, 1);
        curl_setopt($ch_sms, CURLOPT_POSTFIELDS, json_encode(["receivers" => [$phone_number], "smsBody" => "Agusan Dental Registration: Your Verification OTP is $otp_code. Valid for 5 minutes."]));
        curl_setopt($ch_sms, CURLOPT_HTTPHEADER, ["x-api-key: " . TEXTBEE_API_KEY, "Content-Type: application/json"]);
        curl_setopt($ch_sms, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch_sms, CURLOPT_SSL_VERIFYHOST, false);
        curl_exec($ch_sms);
        curl_close($ch_sms);

        $ch_email = curl_init();
        curl_setopt($ch_email, CURLOPT_URL, "https://api.brevo.com/v3/smtp/email");
        curl_setopt($ch_email, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch_email, CURLOPT_POST, 1);
        curl_setopt($ch_email, CURLOPT_POSTFIELDS, json_encode([
            "sender" => ["name" => "Agusan Dental Clinic", "email" => BREVO_SENDER_EMAIL],
            "to" => [["email" => $email]],
            "subject" => "Your Dental Clinic Registration OTP",
            "htmlContent" => "<h3>Welcome to Agusan Dental Clinic!</h3><p>Your Verification OTP is: <strong>$otp_code</strong></p>"
        ]));
        curl_setopt($ch_email, CURLOPT_HTTPHEADER, ["api-key: " . BREVO_API_KEY, "Content-Type: application/json", "accept: application/json"]);
        curl_setopt($ch_email, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch_email, CURLOPT_SSL_VERIFYHOST, false);
        curl_exec($ch_email);
        curl_close($ch_email);
    }

    $response = [
        "status" => "require_otp", 
        "message" => USE_LIVE_APIS ? "Verification code sent to your phone and email." : "DEV MODE: Code saved to database.",
        "email" => $email,
        "phone_number" => substr($phone_number, 0, 6) . '*****' . substr($phone_number, -2)
    ];

    if (!USE_LIVE_APIS) {
        $response["mock_otp"] = $otp_code;
    }

    ob_clean();
    echo json_encode($response);
}
?>