<?php
// File: get_fully_booked_dates.php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include 'db_connect.php';

// Group appointments by date and count them.
// Only count active ones (pending, approved, rescheduled).
// If the count is 9 or more, the whole day is full!
$sql = "
    SELECT appointment_date, COUNT(appointment_id) as total_appointments 
    FROM appointments 
    WHERE status IN ('pending', 'approved', 'rescheduled') 
    GROUP BY appointment_date 
    HAVING total_appointments >= 9
";

$result = $conn->query($sql);

$fully_booked_dates = [];
if ($result && $result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        $fully_booked_dates[] = $row['appointment_date'];
    }
}

echo json_encode($fully_booked_dates);
$conn->close();
?>