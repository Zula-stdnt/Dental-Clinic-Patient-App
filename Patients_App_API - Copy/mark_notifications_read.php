<?php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $patient_id = isset($_POST['patient_id']) ? intval($_POST['patient_id']) : 0;
    
    $sql = "UPDATE sms_notifications s 
            JOIN appointments a ON s.appointment_id = a.appointment_id 
            SET s.is_read = 1 
            WHERE a.patient_id = $patient_id AND s.sender_type = 'admin' AND s.is_read = 0";
            
    if ($conn->query($sql) === TRUE) {
        echo json_encode(["status" => "success"]);
    } else {
        echo json_encode(["status" => "error"]);
    }
}
?>