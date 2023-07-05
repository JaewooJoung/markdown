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
