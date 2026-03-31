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

    if (empty($patient_id)) {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "Missing patient ID."]);
        exit;
    }

    $stmt = $conn->prepare("SELECT phone_number, email FROM patients WHERE patient_id = ?");
    $stmt->bind_param("s", $patient_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result && $result->num_rows > 0) {
        $row = $result->fetch_assoc();
        $phone = $row['phone_number'];
        $email = $row['email'];

        // Generate ONE code
        $otp_code = sprintf("%06d", mt_rand(100000, 999999));
        $expires_at = date("Y-m-d H:i:s", strtotime("+5 minutes"));

        // Save to BOTH columns for unified verification
        $update_stmt = $conn->prepare("UPDATE patients SET phone_otp = ?, email_otp = ?, otp_expires_at = ?, otp_attempts = 0 WHERE patient_id = ?");
        $update_stmt->bind_param("ssss", $otp_code, $otp_code, $expires_at, $patient_id);
        $update_stmt->execute();

        if (USE_LIVE_APIS) {
            // SMS
            $ch_sms = curl_init();
            curl_setopt($ch_sms, CURLOPT_URL, "https://api.textbee.dev/api/v1/gateway/devices/" . TEXTBEE_DEVICE_ID . "/send-sms");
            curl_setopt($ch_sms, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch_sms, CURLOPT_POST, 1);
            curl_setopt($ch_sms, CURLOPT_POSTFIELDS, json_encode(["receivers" => [$phone], "smsBody" => "Password Reset: Your Verification OTP is $otp_code. Valid for 5 minutes."]));
            curl_setopt($ch_sms, CURLOPT_HTTPHEADER, ["x-api-key: " . TEXTBEE_API_KEY, "Content-Type: application/json"]);
            curl_setopt($ch_sms, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch_sms, CURLOPT_SSL_VERIFYHOST, false);
            curl_exec($ch_sms);
            curl_close($ch_sms);

            // Email
            $ch_email = curl_init();
            curl_setopt($ch_email, CURLOPT_URL, "https://api.brevo.com/v3/smtp/email");
            curl_setopt($ch_email, CURLOPT_RETURNTRANSFER, 1);
            curl_setopt($ch_email, CURLOPT_POST, 1);
            curl_setopt($ch_email, CURLOPT_POSTFIELDS, json_encode([
                "sender" => ["name" => "Agusan Dental Clinic", "email" => BREVO_SENDER_EMAIL],
                "to" => [["email" => $email]],
                "subject" => "Your Password Reset OTP",
                "htmlContent" => "<h3>Password Reset Request</h3><p>Your Verification OTP is: <strong>$otp_code</strong></p><p>If you did not request this, please ignore this email.</p>"
            ]));
            curl_setopt($ch_email, CURLOPT_HTTPHEADER, ["api-key: " . BREVO_API_KEY, "Content-Type: application/json", "accept: application/json"]);
            curl_setopt($ch_email, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch_email, CURLOPT_SSL_VERIFYHOST, false);
            curl_exec($ch_email);
            curl_close($ch_email);
        }

        $response = [
            "status" => "success", 
            "message" => USE_LIVE_APIS ? "Verification code sent to your phone and email." : "DEV MODE: Code saved to database.",
            "masked_phone" => substr($phone, 0, 6) . '*****' . substr($phone, -2)
        ];

        if (!USE_LIVE_APIS) {
            $response["mock_otp"] = $otp_code;
        }

        ob_clean();
        echo json_encode($response);
    } else {
        ob_clean();
        echo json_encode(["status" => "error", "message" => "User not found."]);
    }
}
?>