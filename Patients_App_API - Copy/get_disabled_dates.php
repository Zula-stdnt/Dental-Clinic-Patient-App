<?php
// File: get_disabled_dates.php
error_reporting(0);
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");

include 'db_connect.php';

$sql = "SELECT block_date, reason FROM disabled_dates";
$result = $conn->query($sql);

$disabled_dates = [];
if ($result && $result->num_rows > 0) {
    while($row = $result->fetch_assoc()) {
        // We now send BOTH the date and the reason!
        $disabled_dates[] = [
            "date" => $row['block_date'],
            "reason" => empty($row['reason']) ? "Clinic Closed" : $row['reason']
        ];
    }
}

echo json_encode($disabled_dates);
$conn->close();
?>