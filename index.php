<!DOCTYPE html>
<html>
<!-- 📁File 💬 index.html -->
<!-- 📙Brief 💬 the page that works to test TSI function quickly -->
<!-- 🧾Details 💬 Also shows time, location, exact location, which type of road and spits the ratio -->
<!-- 🚩OAuthor 💬 Original Author: Jaewoo Joung/郑在祐(jaewoo.joung@outlook.com) -->
<!-- 👨‍🔧Company 💬 Submited to: Myself in CEVT (jaewoo.joung@cevt.se) -->
<!-- 📆LastDate 💬 2023-04-22 🔄Please support to keep update🔄 -->
<!-- 🏭License 🛑 JSD:Just Simple Distribution (a License made by Jaewoo) -->
<!-- ✅Guarantee 💬 If you buy me a coffee, I will think about it -->
<head>
    <title>CEVT TIS TEST</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/flag-icon-css/3.5.0/css/flag-icon.min.css" />
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css" />

    <style>
        html, body {
            height: 88%;
            margin: 0;
            padding: 0;
        }
        
        * {
            box-sizing: border-box;
            font-family: Arial, sans-serif;
            font-size: 16px;
            color: #333;
        }
        
        .container {
            height: 100%;
            box-sizing: border-box;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            margin: 10px;
        }
        
        .row {
            display: flex;
            flex-direction: row;
            align-items: center;
            justify-content: center;
            margin: 10px;
        }
        
        .radio-group {
            display: flex;
            flex-direction: row;
            align-items: center;
            margin: 10px;
        }
        
        .radio-group label {
            margin-right: 10px;
        }
        
        .button-group {
            display: flex;
            flex-direction: row;
            align-items: center;
            margin: 30px;
        }
        
        .button-group button {
            margin-right: 10px;
            padding: 10px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            color: #fff;
            font-size: 16px;
            font-weight: bold;
        }
        
        .green {
            background-color: green;
        }
        
        .red {
            background-color: red;
        }
        
        .counter {
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            font-weight: bold;
            margin: 10px;
        }
        
        .total {
            background-color: yellow;
            color: blue;
            font-size: 48px;
            font-weight: bold;
            margin: 10px;
        }
        
        .submit {
            margin-top: 20px;
            padding: 10px 20px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            background-color: blue;
            color: #fff;
            font-size: 16px;
            font-weight: bold;
        }
        
        .result {
            font-size: 24px;
            font-weight: bold;
            margin-top: 20px;
        }
        
        .time {
            background-color: black;
            color: lime;
            align-items: center;
            font-size: 18px;
            font-weight: bold;
            margin: 10px;
        }
        
        .remember {
            background-color: yellow;
            color: purple;
            align-items: center;
            font-size: 16px;
            font-weight: bold;
            margin: 10px;
        }
    </style>
</head>
<body>

	<div class="container">
		<div class="center">
		<div><hr><hr><br></div>
		<h1>CEVT 🚧TSI🛑 ⚡RAPID🌠 ⛔TEST🚦</h1>
		  ME SW
		  <select name="MESW">
		    <option value="norem">W/O.REM</option>
		    <option value="rem">/W.REM</option>
		    <option value="na">N/A</option>
		  </select>
		  Zkr HMI SW
		  <select name="ZkrHMI">
		    <option value="1027">1.0.2.7</option>
		    <option value="1032">1.0.3.2</option>
		    <option value="na">N/A</option>
		  </select>
		<hr>
		<div class="radio-group">
			<label for="sun">🌞SUNNY</label>
			<input type="radio" id="sun" name="clima" value="sun">
			<label for="rain">/☔RAINNY</label>
			<input type="radio" id="rain" name="clima" value="rain">
			<label for="snow">/⛄SNOW</label>
			<input type="radio" id="snow" name="clima" value="snow">
		</div>
		<div class="row">
			<div class="time" id="date"></div>
			<div class="time" id="clock"></div>
		</div>
		</div>
		<div class="radio-group">
			<label for="sweden"><i class="flag-icon flag-icon-se"></i>Sverige</label>
			<input type="radio" id="sweden" name="country" value="Sweden">
			<label for="germany">/  <i class="flag-icon flag-icon-de"></i>Germany</label>
			<input type="radio" id="germany" name="country" value="Germany">
			<label for="spain">/  <i class="flag-icon flag-icon-es"></i>España</label>
			<input type="radio" id="spain" name="country" value="spain">
		</div>
		<div class="remember" id="location"></div>
		<div class="radio-group">
			<label for="urban">🏞Urban</label>
			<input type="radio" id="urban" name="area" value="Urban">
			<label for="city">/   🏙City</label>
			<input type="radio" id="city" name="area" value="City">
			<label for="highway">/   <i class="fas fa-road"></i>Highway</label>
			<input type="radio" id="highway" name="area" value="Highway">
		</div>
		<div class="row">
		<div class="total">0</div>
		<div>Kms</div>
		</div>
		<div class="row">
			<div class="button-group">
				<button class="green" id="ok">+TP_D🆗</button>
				<div class="counter" id="ok-counter">0</div>
			</div>
			<div class="button-group">
				<button class="red" id="nok">+FX_D🆖</button>
				<div class="counter" id="nok-counter">0</div>
			</div>
		</div>
		<button class="submit" id="submit-btn">Check Percentage</button>
		<div class="result" id="result"></div>
	</div>
    <script>
	const okButton = document.getElementById('ok');
	const nokButton = document.getElementById('nok');
	const okCounter = document.getElementById('ok-counter');
	const nokCounter = document.getElementById('nok-counter');
	const totalCounter = document.querySelector('.total');
	const submitButton = document.getElementById('submit-btn');
	const result = document.getElementById('result');
	
	let okCount = 0;
	let nokCount = 0;
	
	okButton.addEventListener('click', () => {
		okCount++;
		okCounter.textContent = okCount;
		updateTotal();
	});
	
	nokButton.addEventListener('click', () => {
		nokCount++;
		nokCounter.textContent = nokCount;
		updateTotal();
	});
	
	function updateTotal() {
		totalCounter.textContent = okCount + nokCount;
	}
	
	submitButton.addEventListener('click', () => {
		const okRatio = (okCount / (okCount + nokCount)) * 100;
		const nokRatio = (nokCount / (okCount + nokCount)) * 100;
		result.textContent = `🏁TP_D: ${okRatio.toFixed(2)}%::FX_D: ${nokRatio.toFixed(2)}%`;
	});
	    
      function updateTime() {
        const now = new Date();
        const time = now.toLocaleTimeString();
        const date = now.toLocaleDateString();
        document.getElementById("clock").innerHTML = time;
        document.getElementById("date").innerHTML = date;
      }
      setInterval(updateTime, 1000);
	    
      function showPosition(position) {
        const latitude = position.coords.latitude;
        const longitude = position.coords.longitude;
        document.getElementById("location").innerHTML = "Latitude: " + latitude + "<br>Longitude: " + longitude;
      }
      function showError(error) {
        document.getElementById("location").innerHTML = "Error: " + error.message;
      }
      function updateLocation() {
        navigator.geolocation.getCurrentPosition(showPosition, showError);
      }
      setInterval(updateLocation, 2300); // update location every 2.3 seconds
    
</script>
</body>
</html>
