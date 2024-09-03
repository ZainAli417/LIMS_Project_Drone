import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:project_drone/Constant/weather.dart';

class WeatherController extends GetxController {
  var weather = Weather(
    cityname: "N/A",
    icon: "",
    temp: 0.0,
    humidity: 0,
    windspeed: 0.0,
    condition: "",
  ).obs;

  Future<void> fetchWeatherData(double latitude, double longitude) async {
    try {
      var uri = Uri.parse(
          "http://api.weatherapi.com/v1/current.json?key=afa5323058974cbb9cf151657230504&q=$latitude,$longitude&aqi=no");
      var res = await http.get(uri);

      if (res.statusCode == 200) {
        Weather fetchedWeather = Weather.fromjson(jsonDecode(res.body));
        weather.value = fetchedWeather; // Update the observable weather data
      } else {
        print('Failed to fetch weather data');
      }
    } catch (e) {
      print('Error fetching weather data: $e');
    }
  }
}
