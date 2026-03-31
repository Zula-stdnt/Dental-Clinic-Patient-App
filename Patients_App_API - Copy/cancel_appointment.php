<?php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $appointment_id = isset($_POST['appointment_id']) ? intval($_POST['appointment_id']) : 0;
    
    if ($appointment_id === 0) {
        echo json_encode(["status" => "error", "message" => "Invalid ID"]);
        exit;
    }

    // 1. Update the appointment status
    $sql = "UPDATE appointments SET status = 'cancelled_by_patient' WHERE appointment_id = $appointment_id";
            
    if ($conn->query($sql) === TRUE) {
        
        // 2. Fetch Patient details to send the SMS
        $info_sql = "SELECT p.first_name, p.last_name, p.phone_number, a.service 
                     FROM appointments a 
                     JOIN patients p ON a.patient_id = p.patient_id 
                     WHERE a.appointment_id = $appointment_id";
        $info_result = $conn->query($info_sql);

        if ($info_result && $info_result->num_rows > 0) {
            $info = $info_result->fetch_assoc();
            
            // Format the names
            $patient_name = $conn->real_escape_string($info['first_name'] . ' ' . $info['last_name']);
            $first_name = $info['first_name'];
            $phone = $info['phone_number'];
            $service = $conn->real_escape_string($info['service']);

            // The automated cancellation message
            $message = "Hi $first_name, your appointment for $service has been successfully cancelled. You can easily book a new appointment through the app anytime!";

            // 3. Send via TextBee Gateway
            $deviceId = TEXTBEE_DEVICE_ID; 
            $apiKey   = TEXTBEE_API_KEY;   

            $ch = curl_init("https://api.textbee.dev/api/v1/gateway/devices/$deviceId/send-sms");
            curl_setopt($ch, CURLOPT_HTTPHEADER, ['x-api-key: '.$apiKey, 'Content-Type: application/json']);
            curl_setopt($ch, CURLOPT_POST, 1);
            curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode(['recipients' => [$phone], 'message' => $message]));
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_exec($ch);
            curl_close($ch);

            // 4. Log to sms_notifications (is_read = 0 so the patient gets an in-app alert receipt too!)
            $log_sql = "INSERT INTO sms_notifications (appointment_id, patient_name, service, status, message, is_read, sender_type, sent_at) 
                        VALUES ($appointment_id, '$patient_name', '$service', 'Cancelled', '$message', 0, 'admin', NOW())";
            $conn->query($log_sql);
        }

        echo json_encode(["status" => "success"]);
    } else {
        echo json_encode(["status" => "error"]);
    }
}
?>