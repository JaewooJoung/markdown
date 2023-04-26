<?php
// Get the sensor data from the POST request
$accelX = $_POST["accelX"];
$accelY = $_POST["accelY"];
$accelZ = $_POST["accelZ"];
$gyroX = $_POST["gyroX"];
$gyroY = $_POST["gyroY"];
$gyroZ = $_POST["gyroZ"];

// Connect to the MySQL database
$servername = "localhost";
$username = "yourusername";
$password = "yourpassword";
$dbname = "yourdbname";
$conn = new mysqli($servername, $username, $password, $dbname);

// Check for errors
if ($conn->connect_error) {
  die("Connection failed: " . $conn->connect_error);
}

// Insert the sensor data into the database
$sql = "INSERT INTO sensor_data (accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z, timestamp) VALUES ('$accelX', '$accelY', '$accelZ', '$gyroX', '$gyroY', '$gyroZ', NOW())";

if ($conn->query($sql) === TRUE) {
  echo "Sensor data stored successfully.";
} else {
  echo "Error storing sensor data: " . $conn->error;
}

$conn->close();
?>
