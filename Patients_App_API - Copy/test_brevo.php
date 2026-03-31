<?php
// Force PHP to show all errors on the screen
ini_set('display_errors', 1);
error_reporting(E_ALL);

$brevo_api_key = "YOUR_BREVO_API_KEY_HERE"; // PASTE YOUR KEY HERE
$sender_email = "your-email@example.com"; 

// We will send a test email to yourself to see if it works
$test_recipient = "your-email@example.com"; 

$email_data = [
    "sender" => ["name" => "Clinic Test", "email" => $sender_email],
    "to" => [["email" => $test_recipient]],
    "subject" => "Brevo API Test",
    "htmlContent" => "<p>If you see this, the Brevo API is working perfectly!</p>"
];

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, "https://api.brevo.com/v3/smtp/email");
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_POST, 1);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($email_data));
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    "api-key: " . $brevo_api_key,
    "Content-Type: application/json",
    "accept: application/json"
]);

// Bypass local SSL issues
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);

$response = curl_exec($ch);
$curl_error = curl_error($ch);
curl_close($ch);

echo "<h2>1. Local Connection Error (if any):</h2>";
echo "<pre style='color:red;'>" . print_r($curl_error, true) . "</pre>";

echo "<h2>2. Brevo's Official Reply:</h2>";
echo "<pre style='color:blue; font-size:18px;'>" . print_r(json_decode($response, true), true) . "</pre>";
?>