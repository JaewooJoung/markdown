function calculateSpeed(initialLat, initialLng, initialTimestamp, currentLat, currentLng, currentTimestamp) {
  const earthRadius = 6371000; // Radius of the Earth in meters

  const dLat = (currentLat - initialLat) * Math.PI / 180;
  const dLng = (currentLng - initialLng) * Math.PI / 180;

  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(initialLat * Math.PI / 180) * Math.cos(currentLat * Math.PI / 180) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  const displacement = earthRadius * c;

  const duration = (currentTimestamp - initialTimestamp) / 1000; // Convert milliseconds to seconds

  const speed = displacement / duration;

  return speed;
}

// Function to get the weather and display the icon
function getWeather() {
  // Make a request to the weather API to get the weather data
  // Replace 'YOUR_API_KEY' with your actual API key
  fetch('https://api.weatherapi.com/v1/current.json?key=ad8caecea06c43d1912181938230407&q=Gothenburg')
    .then(response => response.json())
    .then(data => {
      // Get the weather icon code from the API response
      var weatherIcon = data.current.condition.icon;

      // Create an <img> element for the weather icon
      var weatherImg = document.createElement("img");
      weatherImg.src = "https:" + weatherIcon;

      // Append the weather icon to the weatherContainer div
      var weatherContainer = document.getElementById("weatherContainer");
      weatherContainer.appendChild(weatherImg);
    });
}

// Function to start tracking speed and weather
function startTracking() {
  navigator.geolocation.watchPosition(
    function (position) {
      const initialPosition = position.coords;
      const initialTimestamp = position.timestamp;

      // Watch for changes in position
      navigator.geolocation.watchPosition(
        function (position) {
          const currentLat = position.coords.latitude;
          const currentLng = position.coords.longitude;
          const currentTimestamp = position.timestamp;

          const speed = calculateSpeed(
            initialPosition.latitude,
            initialPosition.longitude,
            initialTimestamp,
            currentLat,
            currentLng,
            currentTimestamp
          );

          // Update the speed value on the page
          document.getElementById("speed").textContent = `Speed: ${speed.toFixed(2)} m/s`;

          // Get the weather forecast and display the weather icon
          getWeather();
        },
        errorCallback
      );
    },
    errorCallback
  );
}

function errorCallback(error) {
  console.log(error.message);
}

// Execute the code when the DOM is fully loaded
document.addEventListener("DOMContentLoaded", function () {
  requestLocationPermission();
});
