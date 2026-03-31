<?php
// Force Asia/Manila timezone globally to prevent expiration bugs
date_default_timezone_set('Asia/Manila');
mysqli_report(MYSQLI_REPORT_OFF);

// ==========================================
// DEVELOPER SETTINGS & API KEYS
// ==========================================
// Change to TRUE before your college defense!
define('USE_LIVE_APIS', true); 

// TextBee Credentials
define('TEXTBEE_DEVICE_ID', 'YOUR_TEXTBEE_DEVICE_ID_HERE');
define('TEXTBEE_API_KEY', 'YOUR_TEXTBEE_API_KEY_HERE');

// Brevo Credentials
define('BREVO_API_KEY', 'YOUR_BREVO_API_KEY_HERE');
define('BREVO_SENDER_EMAIL', 'your-email@example.com');

// Database Connection
$host = "localhost";
$user = "YOUR_DATABASE_USER";
$pass = "YOUR_DATABASE_PASSWORD";
$db_name = "YOUR_DATABASE_NAME";

$conn = @new mysqli($host, $user, $pass, $db_name);

if ($conn->connect_error) {
    header('Content-Type: application/json');
    die(json_encode(["status" => "error", "message" => "Database connection failed: " . $conn->connect_error]));
}
?>