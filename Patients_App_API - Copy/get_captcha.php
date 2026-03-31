<?php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

// Generate two random numbers between 1 and 9
$num1 = rand(1, 9);
$num2 = rand(1, 9);

$answer = $num1 + $num2;
$question = "What is $num1 + $num2?";

// We create a secure hash of the answer using a secret "salt" key.
// Even if a bot sees the hash, it cannot guess the answer.
$secret_key = "YOUR_SECRET_SALT_HERE";
$hash = md5($answer . $secret_key);

echo json_encode([
    "question" => $question,
    "hash" => $hash
]);
?>