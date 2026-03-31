<?php
error_reporting(0);
ini_set('display_errors', 0);
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST");
header("Content-Type: application/json");

include 'db_connect.php';

if ($_SERVER['REQUEST_METHOD'] == 'POST') {
    $email = $_POST['email'] ?? '';
    $security_answer = $_POST['security_answer'] ?? '';
    $new_password = $_POST['new_password'] ?? '';

    if (empty($email) || empty($security_answer) || empty($new_password)) {
        echo json_encode(["status" => "error", "message" => "All fields are required."]);
        exit;
    }

    // 1. Backend Password Strength Check
    $password_pattern = '/^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[\W_]).{8,}$/';
    if (!preg_match($password_pattern, $new_password)) {
        echo json_encode([
            "status" => "error", 
            "message" => "Password must include uppercase letters, lowercase letters, numbers, and special characters (Min 8 chars)."
        ]);
        exit;
    }

    // 2. Fetch the stored HASHED security answer
    $stmt = $conn->prepare("SELECT security_answer FROM patients WHERE email = ?");
    $stmt->bind_param("s", $email);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        // 3. Normalize the input (lowercase and trim) just like we did in signup
        $normalized_answer = strtolower(trim($security_answer));

        // 4. Verify the answer
        if (password_verify($normalized_answer, $row['security_answer'])) {
            
            // 5. Hash the new password and save it
            $new_hashed = password_hash($new_password, PASSWORD_DEFAULT);
            $update_stmt = $conn->prepare("UPDATE patients SET password = ? WHERE email = ?");
            $update_stmt->bind_param("ss", $new_hashed, $email);
            
            if ($update_stmt->execute()) {
                echo json_encode(["status" => "success", "message" => "Password reset successfully."]);
            } else {
                echo json_encode(["status" => "error", "message" => "Database error."]);
            }
        } else {
            echo json_encode(["status" => "error", "message" => "Incorrect security answer."]);
        }
    } else {
        echo json_encode(["status" => "error", "message" => "Account not found."]);
    }
}
?>