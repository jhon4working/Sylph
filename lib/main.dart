import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0a0f),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SylphApp());
}

class SylphApp extends StatelessWidget {
  const SylphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sylph — Weather & Air',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF0a0a0f),
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFc8f04e),
          secondary: Color(0xFF4ecbf0),
          surface: Color(0xFF111118),
          background: Color(0xFF0a0a0f),
          error: Color(0xFFf04e6a),
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  CONSTANTS & THEME
// ═══════════════════════════════════════════════════════════
class AppColors {
  static const bg = Color(0xFF0a0a0f);
  static const surface = Color(0xFF111118);
  static const border = Color.fromRGBO(255, 255, 255, 0.07);
  static const text = Color(0xFFf0ede8);
  static const muted = Color.fromRGBO(240, 237, 232, 0.68);
  static const accent = Color(0xFFc8f04e);
  static const accent2 = Color(0xFF4ecbf0);
  static const danger = Color(0xFFf04e6a);
  static const warn = Color(0xFFf0a84e);
  static const good = Color(0xFF4ef09a);
  static const cardTint = Color.fromRGBO(205, 185, 155, 0.13);
  static const cardBorder = Color.fromRGBO(205, 185, 145, 0.22);
}

class AppFonts {
  static TextStyle display({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: -0.02,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    return TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  static TextStyle boldonse({double size = 24, Color? color}) {
    return TextStyle(
      fontFamily: 'Boldonse',
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: 0.04,
    );
  }

  static TextStyle label({double size = 10, Color? color}) {
    return TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColors.muted,
      letterSpacing: 0.25,
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  API KEYS
// ═══════════════════════════════════════════════════════════
const String OWM_KEY = 'fa736ae62b05126fda481140ce2f39ef';
const String WAQI_KEY = '8a0e521b8a539d30e682f61b71cf7413ad20d7ae';

// ═══════════════════════════════════════════════════════════
//  DATA MODELS
// ═══════════════════════════════════════════════════════════
class WeatherData {
  final String city;
  final String country;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int visibility;
  final int pressure;
  final String description;
  final int weatherCode;
  final double lat;
  final double lon;
  final int timezone;
  final DateTime localTime;

  WeatherData({
    required this.city,
    required this.country,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.visibility,
    required this.pressure,
    required this.description,
    required this.weatherCode,
    required this.lat,
    required this.lon,
    required this.timezone,
    required this.localTime,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final tz = json['timezone'] ?? 0;
    final utcMs = DateTime.now().millisecondsSinceEpoch + (DateTime.now().timeZoneOffset.inMilliseconds);
    final localMs = utcMs + (tz * 1000);

    return WeatherData(
      city: json['name'] ?? 'Unknown',
      country: json['sys']?['country'] ?? '',
      temp: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: json['main']?['humidity'] ?? 0,
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      visibility: json['visibility'] ?? 10000,
      pressure: json['main']?['pressure'] ?? 0,
      description: json['weather']?[0]?['description'] ?? 'Unknown',
      weatherCode: json['weather']?[0]?['id'] ?? 800,
      lat: (json['coord']?['lat'] ?? 0).toDouble(),
      lon: (json['coord']?['lon'] ?? 0).toDouble(),
      timezone: tz,
      localTime: DateTime.fromMillisecondsSinceEpoch(localMs.toInt()),
    );
  }
}

class AQIData {
  final int aqi;
  final String? stationName;
  final Map<String, dynamic>? iaqi;

  AQIData({required this.aqi, this.stationName, this.iaqi});

  factory AQIData.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data == null) return AQIData(aqi: 0);

    return AQIData(
      aqi: data['aqi'] is int ? data['aqi'] : int.tryParse(data['aqi'].toString()) ?? 0,
      stationName: data['city']?['name'],
      iaqi: data['iaqi'],
    );
  }
}

class HistoryItem {
  final String city;
  final String country;
  final double tempC;
  final String description;
  final int? aqiNum;
  final DateTime timestamp;

  HistoryItem({
    required this.city,
    required this.country,
    required this.tempC,
    required this.description,
    this.aqiNum,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'city': city,
    'country': country,
    'tempC': tempC,
    'description': description,
    'aqiNum': aqiNum,
    'ts': timestamp.millisecondsSinceEpoch,
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    city: json['city'],
    country: json['country'] ?? '',
    tempC: json['tempC'].toDouble(),
    description: json['description'],
    aqiNum: json['aqiNum'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['ts']),
  );
}

// ═══════════════════════════════════════════════════════════
//  STORAGE SERVICE
// ═══════════════════════════════════════════════════════════
class StorageService {
  static const String _historyKey = 'sylph_history';
  static const String _prefsKey = 'sylph_prefs';

  static Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_historyKey);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => HistoryItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(List<HistoryItem> history) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_historyKey, encoded);
  }

  static Future<void> addToHistory(HistoryItem item) async {
    var history = await loadHistory();
    history.removeWhere((h) => h.city == item.city && h.country == item.country);
    history.insert(0, item);
    if (history.length > 20) history = history.sublist(0, 20);
    await saveHistory(history);
  }

  static Future<Map<String, dynamic>> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return {};
    try {
      return jsonDecode(jsonStr);
    } catch (_) {
      return {};
    }
  }

  static Future<void> savePrefs(Map<String, dynamic> prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(prefs));
  }
}

// ═══════════════════════════════════════════════════════════
//  API SERVICE
// ═══════════════════════════════════════════════════════════
class ApiService {
  static Future<WeatherData> fetchWeather(String city) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city)}&appid=$OWM_KEY&units=metric',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) {
      throw Exception('City not found: "$city". Please try a different name.');
    }
    return WeatherData.fromJson(jsonDecode(response.body));
  }

  static Future<AQIData?> fetchAQI(String city) async {
    try {
      final url = Uri.parse(
        'https://api.waqi.info/feed/${Uri.encodeComponent(city)}/?token=$WAQI_KEY',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data['status'] != 'ok') return null;
      return AQIData.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  UTILITY FUNCTIONS
// ═══════════════════════════════════════════════════════════
String toF(double c) => (c * 9 / 5 + 32).round().toString();

class AQIInfo {
  final String label;
  final Color color;
  final Color bgColor;
  final Color dotColor;

  AQIInfo(this.label, this.color, this.bgColor, this.dotColor);
}

AQIInfo getAQIInfo(int val) {
  if (val <= 50) return AQIInfo('Good', AppColors.good, const Color.fromRGBO(78, 240, 154, 0.12), AppColors.good);
  if (val <= 100) return AQIInfo('Moderate', AppColors.warn, const Color.fromRGBO(240, 168, 78, 0.12), AppColors.warn);
  if (val <= 150) return AQIInfo('Unhealthy for Some', const Color(0xFFf07f4e), const Color.fromRGBO(240, 127, 78, 0.12), const Color(0xFFf07f4e));
  if (val <= 200) return AQIInfo('Unhealthy', AppColors.danger, const Color.fromRGBO(240, 78, 106, 0.12), AppColors.danger);
  if (val <= 300) return AQIInfo('Very Unhealthy', const Color(0xFFb34ef0), const Color.fromRGBO(179, 78, 240, 0.12), const Color(0xFFb34ef0));
  return AQIInfo('Hazardous', const Color(0xFFcc0000), const Color.fromRGBO(123, 0, 0, 0.2), const Color(0xFFcc0000));
}

class UVInfo {
  final String val;
  final String label;
  UVInfo(this.val, this.label);
}

UVInfo estimateUV(int code, double temp) {
  if (code == 800 && temp > 25) return UVInfo('High', 'SPF recommended');
  if (code == 800) return UVInfo('Moderate', 'Light protection needed');
  if (code >= 801 && code < 803) return UVInfo('Low-Mod', 'Minimal risk');
  return UVInfo('Low', 'Safe outdoors');
}

class OutfitInfo {
  final String emoji;
  final String headline;
  final List<String> tags;
  OutfitInfo(this.emoji, this.headline, this.tags);
}

OutfitInfo getOutfit(double temp, int humidity, double wind, int code) {
  final isRain = code >= 300 && code < 700;
  final isSnow = code >= 600 && code < 700;
  if (isSnow || temp < 0) return OutfitInfo('🥶', 'Max layers. Every single one.', ['Heavy coat', 'Thermal base', 'Gloves', 'Beanie', 'Warm boots']);
  if (temp < 8) return OutfitInfo('🧤', 'Coat weather. No debate.', ['Warm coat', 'Jumper', 'Scarf', 'Closed shoes']);
  if (temp < 16) return OutfitInfo('🧥', 'Jacket territory.', ['Light jacket', 'Jeans', 'Closed shoes']);
  if (isRain) return OutfitInfo('🌧️', 'Waterproof up.', ['Waterproof jacket', 'Closed shoes', 'Umbrella']);
  if (temp > 34) return OutfitInfo('😮‍💨', 'As little as socially acceptable.', ['Linen/cotton', 'Light colours', 'Sandals', 'SPF 50+']);
  if (temp > 27) return OutfitInfo('😎', "Light layers, you're good to go.", ['T-shirt', 'Shorts/chinos', 'Sunglasses']);
  return OutfitInfo('🙂', 'Comfortable out there.', ['Light top', 'Trousers or jeans', 'Comfortable shoes']);
}

List<Map<String, dynamic>> getActivities(double temp, int humidity, double wind, int? aqi, int code) {
  final isRain = code >= 300 && code < 700;
  final isStorm = code >= 200 && code < 300;
  final isClear = code == 800;
  final isHot = temp > 32;
  final isCold = temp < 5;
  final isWind = wind > 8;
  final aqiOk = aqi == null || aqi <= 100;
  final aqiBad = aqi != null && aqi > 150;

  final all = [
    {'name': 'Cycling', 'note': 'Great for open air', 'cond': !isRain && !isStorm && !isHot && !isWind && aqiOk, 'icon': Icons.pedal_bike},
    {'name': 'Running', 'note': 'Moderate intensity', 'cond': !isRain && !isStorm && !isHot && aqiOk, 'icon': Icons.directions_run},
    {'name': 'Hiking', 'note': 'Nature & cardio', 'cond': !isRain && !isStorm && !isHot && !isCold && aqiOk, 'icon': Icons.hiking},
    {'name': 'Swimming', 'note': 'Beats the heat', 'cond': isHot && !isRain && aqiOk, 'icon': Icons.pool},
    {'name': 'Indoor Yoga', 'note': 'Calm & flexible', 'cond': isRain || isStorm || aqiBad || isHot || isCold, 'icon': Icons.self_improvement},
    {'name': 'Gym Workout', 'note': 'All-weather option', 'cond': isRain || isStorm || aqiBad || isHot || isCold, 'icon': Icons.fitness_center},
    {'name': 'Walking', 'note': 'Light & refreshing', 'cond': !isRain && !isStorm && !isHot && aqiOk, 'icon': Icons.directions_walk},
    {'name': 'Rock Climbing', 'note': 'Dry conditions ideal', 'cond': isClear && !isHot && !isWind && aqiOk, 'icon': Icons.terrain},
    {'name': 'Meditation', 'note': 'Indoor mindfulness', 'cond': aqiBad || isRain, 'icon': Icons.spa},
    {'name': 'Skiing', 'note': 'Snow conditions', 'cond': code >= 600 && code < 700, 'icon': Icons.downhill_skiing},
  ];

  return all.where((a) => a['cond'] as bool).take(6).toList();
}

List<Map<String, dynamic>> getPrecautions(double temp, int humidity, double wind, int? aqi, int code) {
  final precs = <Map<String, dynamic>>[];
  final isRain = code >= 300 && code < 600;
  final isStorm = code >= 200 && code < 300;
  final isSnow = code >= 600 && code < 700;
  final isFog = code >= 700 && code < 800;

  if (temp > 35) precs.add({'color': AppColors.danger, 'text': 'Extreme heat alert. Limit outdoor activity 11am-4pm. Stay hydrated and seek shade.'});
  else if (temp > 30) precs.add({'color': const Color(0xFFf07f4e), 'text': 'High temperature. Carry water, wear light clothing, and use sunscreen SPF 30+.'});
  if (temp < 0) precs.add({'color': const Color(0xFF4e9af0), 'text': 'Below freezing. Risk of ice on surfaces. Dress in warm layers and protect extremities.'});
  else if (temp < 5) precs.add({'color': const Color(0xFF4e9af0), 'text': 'Cold conditions. Wear insulated clothing. Limit prolonged outdoor exposure.'});
  if (humidity > 80) precs.add({'color': AppColors.warn, 'text': 'High humidity. Physical exertion may feel more strenuous. Take regular breaks and cool down.'});
  if (wind > 10) precs.add({'color': AppColors.accent2, 'text': 'Strong winds. Avoid exposed ridges or elevated areas. Secure loose objects outdoors.'});
  if (isStorm) precs.add({'color': AppColors.danger, 'text': 'Thunderstorm warning. Stay indoors. Avoid tall trees, open fields, and bodies of water.'});
  if (isRain) precs.add({'color': const Color(0xFF4e9af0), 'text': 'Wet conditions. Roads may be slippery. Reduce speed and carry waterproof gear.'});
  if (isSnow) precs.add({'color': const Color(0xFFa8d8f0), 'text': 'Snowfall. Dress in waterproof layers. Allow extra travel time and watch for icy patches.'});
  if (isFog) precs.add({'color': const Color(0xFF888888), 'text': 'Low visibility fog. Use fog lights while driving. Walk on designated paths only.'});
  if (aqi != null) {
    if (aqi > 300) precs.add({'color': const Color(0xFFcc0000), 'text': 'Hazardous air. Stay indoors. Use air purifiers. Wear N95 masks if outdoor travel is essential.'});
    else if (aqi > 200) precs.add({'color': const Color(0xFFb34ef0), 'text': 'Very unhealthy air. Everyone should avoid all outdoor activity. N95 mask required outside.'});
    else if (aqi > 150) precs.add({'color': AppColors.danger, 'text': 'Unhealthy air quality. Avoid outdoor exercise. Sensitive groups must stay indoors.'});
    else if (aqi > 100) precs.add({'color': const Color(0xFFf07f4e), 'text': 'Air quality affecting sensitive groups. Children, elderly, and those with respiratory conditions should limit outdoor activity.'});
  }
  if (precs.isEmpty) precs.add({'color': AppColors.good, 'text': 'Conditions look good! No major precautions needed. Enjoy your day.'});
  return precs;
}

String getGreeting(int hour) {
  if (hour < 5) return 'Up late?';
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  if (hour < 21) return 'Good evening';
  return 'Good night';
}


// ═══════════════════════════════════════════════════════════
//  WEATHER ICON WIDGETS
// ═══════════════════════════════════════════════════════════
class WeatherIcon extends StatelessWidget {
  final int code;
  final double size;

  const WeatherIcon({super.key, required this.code, this.size = 80});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _buildIcon(),
    );
  }

  Widget _buildIcon() {
    if (code >= 200 && code < 300) return _stormIcon();
    if (code >= 300 && code < 600) return _rainIcon();
    if (code >= 600 && code < 700) return _snowIcon();
    if (code >= 700 && code < 800) return _fogIcon();
    if (code == 800) return _sunIcon();
    if (code >= 801 && code < 900) return _cloudIcon();
    return _defaultIcon();
  }

  Widget _stormIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size * 0.6,
          height: size * 0.35,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(80, 100, 180, 0.18),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(color: const Color.fromRGBO(100, 130, 220, 0.45), width: 1.5),
          ),
        ),
        Positioned(
          top: size * 0.45,
          child: CustomPaint(
            size: Size(size * 0.3, size * 0.35),
            painter: LightningPainter(),
          ),
        ),
      ],
    );
  }

  Widget _rainIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _cloudShape(size * 0.7, const Color.fromRGBO(100, 140, 190, 0.18), const Color.fromRGBO(120, 160, 200, 0.4)),
        Positioned(
          top: size * 0.55,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) => Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.06),
              child: Container(
                width: 2,
                height: size * 0.18,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color.fromRGBO(78, 150, 240, 0.75), Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            )),
          ),
        ),
      ],
    );
  }

  Widget _snowIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        _cloudShape(size * 0.65, const Color.fromRGBO(200, 220, 240, 0.2), const Color.fromRGBO(200, 220, 240, 0.45)),
        ...List.generate(5, (i) {
          final positions = [
            Offset(-size * 0.2, size * 0.15),
            Offset(0.0, size * 0.2),
            Offset(size * 0.2, size * 0.15),
            Offset(-size * 0.1, size * 0.35),
            Offset(size * 0.1, size * 0.35),
          ];
          return Positioned(
            left: size * 0.5 + positions[i].dx - 4,
            top: size * 0.4 + positions[i].dy,
            child: Container(
              width: 8 - i * 0.8,
              height: 8 - i * 0.8,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(200, 230, 255, 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _fogIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        width: size * (0.7 - i * 0.08),
        height: size * 0.06,
        decoration: BoxDecoration(
          color: Color.fromRGBO(180, 190, 200, 0.25 - i * 0.04),
          borderRadius: BorderRadius.circular(size * 0.03),
        ),
      )),
    );
  }

  Widget _sunIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ...List.generate(8, (i) {
          final angle = i * 45 * 3.14159 / 180;
          return Transform.translate(
            offset: Offset(
              cos(angle) * size * 0.25,
              sin(angle) * size * 0.25,
            ),
            child: Container(
              width: size * 0.08,
              height: size * 0.03,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(240, 200, 78, 0.65),
                borderRadius: BorderRadius.circular(size * 0.015),
              ),
            ),
          );
        }),
        Container(
          width: size * 0.35,
          height: size * 0.35,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(240, 200, 78, 0.55),
            borderRadius: BorderRadius.circular(size * 0.2),
            border: Border.all(color: const Color.fromRGBO(240, 190, 60, 0.7), width: 1.5),
          ),
        ),
        Container(
          width: size * 0.22,
          height: size * 0.22,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 220, 100, 0.6),
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
        ),
      ],
    );
  }

  Widget _cloudIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: size * 0.15,
          top: size * 0.25,
          child: _cloudShape(size * 0.45, const Color.fromRGBO(150, 170, 190, 0.18), const Color.fromRGBO(150, 170, 190, 0.3)),
        ),
        Positioned(
          left: size * 0.3,
          top: size * 0.15,
          child: _cloudShape(size * 0.55, const Color.fromRGBO(170, 185, 200, 0.18), const Color.fromRGBO(170, 185, 200, 0.3)),
        ),
        Positioned(
          left: size * 0.45,
          top: size * 0.3,
          child: _cloudShape(size * 0.4, const Color.fromRGBO(150, 170, 190, 0.15), const Color.fromRGBO(150, 170, 190, 0.28)),
        ),
      ],
    );
  }

  Widget _defaultIcon() {
    return Container(
      width: size * 0.5,
      height: size * 0.6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.1),
        border: Border.all(color: const Color.fromRGBO(200, 200, 200, 0.4), width: 1.5),
      ),
    );
  }

  Widget _cloudShape(double sz, Color fill, Color stroke) {
    return Container(
      width: sz,
      height: sz * 0.55,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(sz * 0.3),
        border: Border.all(color: stroke, width: 1.5),
      ),
    );
  }
}

class LightningPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFf0e04e)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.6, 0)
      ..lineTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.5)
      ..lineTo(size.width * 0.1, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
//  ANIMATED BACKGROUND ORBS
// ═══════════════════════════════════════════════════════════
class AnimatedOrbs extends StatefulWidget {
  final int weatherCode;
  final double temp;

  AnimatedOrbs({required this.weatherCode, required this.temp});

  @override
  State<AnimatedOrbs> createState() => _AnimatedOrbsState();
}

class _AnimatedOrbsState extends State<AnimatedOrbs>
    with TickerProviderStateMixin {
  late AnimationController _ctrl1;
  late AnimationController _ctrl2;
  late AnimationController _ctrl3;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(vsync: this, duration: const Duration(seconds: 14));
    _ctrl2 = AnimationController(vsync: this, duration: const Duration(seconds: 18));
    _ctrl3 = AnimationController(vsync: this, duration: const Duration(seconds: 22));
    _ctrl1.repeat(reverse: true);
    _ctrl2.repeat(reverse: true);
    _ctrl3.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  List<Color> get _orbColors {
    final code = widget.weatherCode;
    final temp = widget.temp;

    if (code >= 200 && code < 300) return [const Color(0xFF4e8af0), const Color(0xFF7b4ef0)];
    if (code >= 300 && code < 600) return [const Color(0xFF4e9af0), const Color(0xFF4ef0e8)];
    if (code >= 600 && code < 700) return [const Color(0xFFa8d8f0), const Color(0xFFc8e8ff)];
    if (temp > 30) return [const Color(0xFFf09a4e), const Color(0xFFf04e6a)];
    if (temp < 5) return [const Color(0xFF4e9af0), const Color(0xFFa8d8f0)];
    return [AppColors.accent2, AppColors.accent];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _orbColors;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        AnimatedBuilder(
          animation: _ctrl1,
          builder: (context, child) {
            final t = _ctrl1.value;
            return Positioned(
              top: -size.height * 0.15 + sin(t * 3.14159 * 2) * 40,
              left: -size.width * 0.2 + cos(t * 3.14159 * 2) * 60,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[0].withOpacity(0.10),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _ctrl2,
          builder: (context, child) {
            final t = _ctrl2.value;
            return Positioned(
              bottom: -size.height * 0.12 + sin(t * 3.14159 * 2 + 1) * 50,
              right: -size.width * 0.15 + cos(t * 3.14159 * 2 + 1) * 70,
              child: Container(
                width: size.width * 0.65,
                height: size.width * 0.65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[1].withOpacity(0.10),
                ),
              ),
            );
          },
        ),
        AnimatedBuilder(
          animation: _ctrl3,
          builder: (context, child) {
            final t = _ctrl3.value;
            return Positioned(
              top: size.height * 0.35 + sin(t * 3.14159 * 2 + 2) * 30,
              left: size.width * 0.3 + cos(t * 3.14159 * 2 + 2) * 20,
              child: Container(
                width: size.width * 0.35,
                height: size.width * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFb34ef0).withOpacity(0.06 + t * 0.05),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SKY GRADIENT BACKGROUND
// ═══════════════════════════════════════════════════════════
class SkyGradient extends StatelessWidget {
  final int weatherCode;
  final int timezone;

  SkyGradient({required this.weatherCode, required this.timezone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _getColors(),
        ),
      ),
    );
  }

  List<Color> _getColors() {
    final utcMs = DateTime.now().millisecondsSinceEpoch + DateTime.now().timeZoneOffset.inMilliseconds;
    final local = DateTime.fromMillisecondsSinceEpoch(utcMs + timezone * 1000);
    final h = local.hour + local.minute / 60;

    final isRain = weatherCode >= 300 && weatherCode < 700;
    final isStorm = weatherCode >= 200 && weatherCode < 300;
    final isFog = weatherCode >= 700 && weatherCode < 800;
    final isClear = weatherCode == 800;

    if (isStorm) return [const Color(0xFF0c0e1a), const Color(0xFF1a1f3c), const Color(0xFF2a2040)];
    if (isRain) return [const Color(0xFF111827), const Color(0xFF1e2a38), const Color(0xFF2c3a4a)];
    if (isFog) return [const Color(0xFF1a1e2a), const Color(0xFF2d3344), const Color(0xFF3a4050)];

    if (h >= 5 && h < 7) {
      return [const Color(0xFF1a1428), const Color(0xFF8b4f72), const Color(0xFFe8906a), const Color(0xFFf8d4a0)];
    } else if (h >= 7 && h < 10) {
      return [const Color(0xFF2a4a6e), const Color(0xFF4a7fa0), const Color(0xFFa8cce0), const Color(0xFFf0e0c8)];
    } else if (h >= 10 && h < 16) {
      return isClear
          ? [const Color(0xFF6aaed6), const Color(0xFF8ec8e8), const Color(0xFFb8ddf0), const Color(0xFFd8eef8)]
          : [const Color(0xFF7ab0cc), const Color(0xFF9ec4d8), const Color(0xFFc0d8e8), const Color(0xFFd8e8f0)];
    } else if (h >= 16 && h < 18.5) {
      return [const Color(0xFF1a3050), const Color(0xFFc86020), const Color(0xFFf0a050), const Color(0xFFf8d890)];
    } else if (h >= 18.5 && h < 21) {
      return [const Color(0xFF1a1030), const Color(0xFF6a2858), const Color(0xFFc04040), const Color(0xFFf08060)];
    }
    return [const Color(0xFF060810), const Color(0xFF0a0c18), const Color(0xFF0e1020)];
  }
}


// ═══════════════════════════════════════════════════════════
//  MAIN HOME PAGE
// ═══════════════════════════════════════════════════════════
class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage>
    with TickerProviderStateMixin {
  final TextEditingController _cityController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  WeatherData? _weather;
  AQIData? _aqi;
  String _currentUnit = 'C';
  Map<String, dynamic> _prefs = {};
  List<HistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _prefs = await StorageService.loadPrefs();
    _history = await StorageService.loadHistory();
    setState(() {
      _currentUnit = _prefs['unit'] ?? 'C';
    });

    if (_prefs['onboarded'] != true) {
      Future.delayed(const Duration(milliseconds: 700), () {
        _showOnboarding();
      });
    } else if (_prefs['homeCity'] != null) {
      _cityController.text = _prefs['homeCity'];
      _fetchData();
    }
  }

  void _showOnboarding() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OnboardingSheet(
        onComplete: (name, city) async {
          _prefs['userName'] = name;
          _prefs['homeCity'] = city;
          _prefs['onboarded'] = true;
          await StorageService.savePrefs(_prefs);
          setState(() {});
          if (city.isNotEmpty) {
            _cityController.text = city;
            _fetchData();
          }
        },
        onSkip: () async {
          _prefs['onboarded'] = true;
          await StorageService.savePrefs(_prefs);
          setState(() {});
        },
      ),
    );
  }

  Future<void> _fetchData() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchWeather(city),
        ApiService.fetchAQI(city),
      ]);

      setState(() {
        _weather = results[0] as WeatherData;
        _aqi = results[1] as AQIData?;
        _isLoading = false;
      });

      await StorageService.addToHistory(HistoryItem(
        city: _weather!.city,
        country: _weather!.country,
        tempC: _weather!.temp,
        description: _weather!.description,
        aqiNum: _aqi?.aqi,
        timestamp: DateTime.now(),
      ));
      _history = await StorageService.loadHistory();
      setState(() {});
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _setUnit(String unit) {
    setState(() {
      _currentUnit = unit;
    });
    _prefs['unit'] = unit;
    StorageService.savePrefs(_prefs);
  }

  String _formatTemp(double c) {
    if (_currentUnit == 'F') return toF(c);
    return c.round().toString();
  }

  String _getSym() => _currentUnit == 'C' ? '°C' : '°F';

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getGreeting(hour),
              style: AppFonts.display(size: 28),
            ),
            if (_prefs['userName'] != null)
              Text(
                _prefs['userName'],
                style: AppFonts.body(size: 14, color: AppColors.muted),
              ),
          ],
        ),
        _iconButton(Icons.settings, _showSettings),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _cityController,
        style: AppFonts.body(),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          hintText: 'Search location...',
          hintStyle: AppFonts.body(color: AppColors.muted),
          suffixIcon: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: _iconButton(Icons.search, _fetchData),
                ),
        ),
        onSubmitted: (_) => _fetchData(),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
      ),
      child: Text(
        _error!,
        style: AppFonts.body(size: 13, color: AppColors.danger),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Fetching weather data...',
            style: AppFonts.body(size: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final w = _weather!;
    final tempV = _formatTemp(w.temp);
    final feelsV = _formatTemp(w.feelsLike);
    final sym = _getSym();
    final outfit = getOutfit(w.temp, w.humidity, w.windSpeed, w.weatherCode);
    final uv = estimateUV(w.weatherCode, w.temp);
    final acts = getActivities(w.temp, w.humidity, w.windSpeed, _aqi?.aqi, w.weatherCode);
    final precs = getPrecautions(w.temp, w.humidity, w.windSpeed, _aqi?.aqi, w.weatherCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNow(),
        const SizedBox(height: 20),
        _buildAQI(),
        const SizedBox(height: 20),
        _buildLeavingNow(outfit, tempV, feelsV, sym, uv),
        const SizedBox(height: 20),
        _buildActivities(acts),
        const SizedBox(height: 20),
        _buildPrecautions(precs),
        const SizedBox(height: 20),
        _buildFooter(),
      ],
    );
  }

  Widget _buildNow() {
    final w = _weather!;
    final tempV = _formatTemp(w.temp);
    final sym = _getSym();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WeatherIcon(code: w.weatherCode, size: 80),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tempV,
                        style: AppFonts.display(size: 60),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          sym,
                          style: AppFonts.display(size: 24),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${w.city}, ${w.country}',
                    style: AppFonts.body(size: 14, color: AppColors.muted),
                  ),
                  Text(
                    w.description,
                    style: AppFonts.body(size: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAQI() {
    if (_aqi == null || _aqi!.aqi == 0) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'AQI data unavailable',
          style: AppFonts.body(size: 13, color: AppColors.muted),
        ),
      );
    }

    final info = getAQIInfo(_aqi!.aqi);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: info.bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: info.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.dotColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Air Quality: ${info.label}',
                  style: AppFonts.body(size: 12, weight: FontWeight.w700, color: info.color),
                ),
                if (_aqi!.stationName != null)
                  Text(
                    'Station: ${_aqi!.stationName}',
                    style: AppFonts.body(size: 10, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          Text(
            '${_aqi!.aqi}',
            style: AppFonts.body(size: 18, weight: FontWeight.w700, color: info.color),
          ),
        ],
      ),
    );
  }

  Widget _buildLeavingNow(OutfitInfo outfit, String tempV, String feelsV, String sym, UVInfo uv) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOW',
          style: AppFonts.label(size: 10),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildLeavingNowRow(outfit.emoji, 'What to wear', outfit.headline, outfit.tags.join(' · ')),
              _buildLeavingNowRow(
                '🌤️',
                'UV index',
                uv.val,
                uv.label,
              ),
              _buildLeavingNowRow('🌡️', 'Feels like', '$feelsV$sym', 'Actual $tempV$sym · Humidity ${_weather!.humidity}%'),
              _buildLeavingNowRow(
                '💨',
                'Wind speed',
                '${_weather!.windSpeed.round()} m/s',
                'Pressure ${_weather!.pressure} mb',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeavingNowRow(String emoji, String label, String value, String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppFonts.label(size: 10)),
                const SizedBox(height: 3),
                Text(value, style: AppFonts.body(size: 16, weight: FontWeight.w700)),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: AppFonts.body(size: 13, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivities(List<Map<String, dynamic>> acts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECOMMENDED',
          style: AppFonts.label(size: 10),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: acts.map((a) {
            return Chip(
              avatar: Icon(a['icon'] as IconData, size: 16, color: AppColors.accent),
              label: Text(a['name'].toString()),
              labelStyle: AppFonts.body(size: 12),
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrecautions(List<Map<String, dynamic>> precs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRECAUTIONS',
          style: AppFonts.label(size: 10),
        ),
        const SizedBox(height: 8),
        ...precs.map((p) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (p['color'] as Color).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (p['color'] as Color).withOpacity(0.3)),
              ),
              child: Text(
                p['text'].toString(),
                style: AppFonts.body(size: 13, color: p['color'] as Color),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            height: 1,
            color: AppColors.border,
            margin: const EdgeInsets.only(bottom: 20),
          ),
          Text(
            'Sylph — Live data via OpenWeatherMap & WAQI',
            style: AppFonts.body(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Text(
            'Built by Vijayarka',
            style: AppFonts.body(size: 11, color: AppColors.accent),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SettingsSheet(
        prefs: _prefs,
        history: _history,
        currentUnit: _currentUnit,
        onUnitChange: _setUnit,
        onPrefsUpdate: (p) async {
          _prefs = p;
          await StorageService.savePrefs(p);
          setState(() {});
        },
        onHistoryUpdate: (h) async {
          _history = h;
          await StorageService.saveHistory(h);
          setState(() {});
        },
        onLoadCity: (city) {
          _cityController.text = city;
          _fetchData();
        },
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: AppColors.accent, size: 24),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_weather != null)
            SkyGradient(weatherCode: _weather!.weatherCode, timezone: _weather!.timezone),
          if (_weather != null)
            AnimatedOrbs(weatherCode: _weather!.weatherCode, temp: _weather!.temp),
          Container(
            color: _weather == null ? AppColors.bg : Colors.transparent,
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildSearch(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildError(),
                  ],
                  if (_isLoading) ...[
                    const SizedBox(height: 80),
                    _buildLoader(),
                  ],
                  if (_weather != null && !_isLoading) ...[
                    const SizedBox(height: 28),
                    _buildResults(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
//  SETTINGS SHEET
// ═══════════════════════════════════════════════════════════
class SettingsSheet extends StatefulWidget {
  final Map<String, dynamic> prefs;
  final List<HistoryItem> history;
  final String currentUnit;
  final Function(String) onUnitChange;
  final Function(Map<String, dynamic>) onPrefsUpdate;
  final Function(List<HistoryItem>) onHistoryUpdate;
  final Function(String) onLoadCity;

  SettingsSheet({
    required this.prefs,
    required this.history,
    required this.currentUnit,
    required this.onUnitChange,
    required this.onPrefsUpdate,
    required this.onHistoryUpdate,
    required this.onLoadCity,
  });

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Settings',
                  style: AppFonts.display(size: 24),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: AppColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Temperature Unit',
              style: AppFonts.label(size: 10),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _unitButton('°C', widget.currentUnit == 'C', () => widget.onUnitChange('C')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _unitButton('°F', widget.currentUnit == 'F', () => widget.onUnitChange('F')),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Search History',
              style: AppFonts.label(size: 10),
            ),
            const SizedBox(height: 8),
            if (widget.history.isEmpty)
              Text(
                'No history yet',
                style: AppFonts.body(size: 13, color: AppColors.muted),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.history.map((h) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        widget.onLoadCity(h.city);
                        Navigator.pop(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${h.city}, ${h.country}',
                                  style: AppFonts.body(size: 13, weight: FontWeight.w500),
                                ),
                                Text(
                                  '${h.tempC.round()}° · ${h.description}',
                                  style: AppFonts.body(size: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final updated = widget.history.where((x) => x != h).toList();
                              widget.onHistoryUpdate(updated);
                              setState(() {});
                            },
                            color: AppColors.danger,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _unitButton(String label, bool isActive, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w600,
                color: isActive ? AppColors.bg : AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════
//  ONBOARDING SHEET
// ═══════════════════════════════════════════════════════════
class OnboardingSheet extends StatefulWidget {
  final Function(String, String) onComplete;
  final VoidCallback onSkip;

  OnboardingSheet({
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Sylph',
              style: AppFonts.display(size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Your personal weather companion',
              style: AppFonts.body(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            Text(
              'Your name',
              style: AppFonts.label(size: 10),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: AppFonts.body(),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Enter your name',
                hintStyle: AppFonts.body(color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Home city',
              style: AppFonts.label(size: 10),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              style: AppFonts.body(),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                hintText: 'Search your city...',
                hintStyle: AppFonts.body(color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onSkip();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Skip',
                    style: AppFonts.body(size: 14, color: AppColors.muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onComplete(_nameController.text, _cityController.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Continue',
                    style: AppFonts.body(size: 14, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}
