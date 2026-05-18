import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

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
    return GoogleFonts.boldonse(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: -0.02,
    );
  }

  static TextStyle body({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.text,
    );
  }

  static TextStyle boldonse({double size = 24, Color? color}) {
    return GoogleFonts.boldonse(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColors.text,
      letterSpacing: 0.04,
    );
  }

  static TextStyle label({double size = 10, Color? color}) {
    return GoogleFonts.dmSans(
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
      localTime: DateTime.fromMillisecondsSinceEpoch(localMs),
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
    else if (aqi > 100) precs.add({'color': const Color(0xFFf07f4e), 'text': 'Air quality affecting sensitive groups. Children, elderly, and those with respiratory conditions should limit outdoor time.'});
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

  const AnimatedOrbs({super.key, required this.weatherCode, required this.temp});

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

  const SkyGradient({super.key, required this.weatherCode, required this.timezone});

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

  Widget _buildHeader() {
    final hour = DateTime.now().hour;
    final greeting = getGreeting(hour);
    final name = _prefs['userName'] ?? '';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: 'Syl', style: AppFonts.boldonse(size: 28)),
                  TextSpan(text: 'ph', style: AppFonts.boldonse(size: 28, color: AppColors.accent)),
                ],
              ),
            ),
            if (name.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$greeting, $name 👋',
                  style: AppFonts.body(size: 14, color: const Color.fromRGBO(240, 237, 232, 0.88)),
                ),
              ),
            if (_prefs['homeCity'] != null)
              GestureDetector(
                onTap: () {
                  _cityController.text = _prefs['homeCity'];
                  _fetchData();
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(200, 240, 78, 0.07),
                    border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.22)),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home, size: 10, color: AppColors.accent),
                      const SizedBox(width: 5),
                      Text(
                        _prefs['homeCity'],
                        style: AppFonts.label(size: 10, color: AppColors.accent),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(100),
              ),
              padding: const EdgeInsets.all(3),
              child: Row(
                children: [
                  _unitButton('C'),
                  _unitButton('F'),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _iconButton(Icons.settings, _showSettings),
          ],
        ),
      ],
    );
  }

  Widget _unitButton(String unit) {
    final isActive = _currentUnit == unit;
    return GestureDetector(
      onTap: () => _setUnit(unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '°$unit',
          style: AppFonts.body(
            size: 13,
            weight: FontWeight.w500,
            color: isActive ? AppColors.bg : AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppColors.muted),
      ),
    );
  }

  Widget _buildSearch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(100),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(Icons.search, size: 18, color: Colors.white.withOpacity(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _cityController,
              style: AppFonts.body(size: 16, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Enter a city — Tokyo, London, New York…',
                hintStyle: AppFonts.body(size: 16, color: AppColors.muted),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _fetchData(),
            ),
          ),
          GestureDetector(
            onTap: _fetchData,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'SEARCH',
                style: AppFonts.body(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.bg,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'FETCHING ATMOSPHERE DATA',
            style: AppFonts.label(size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(240, 78, 106, 0.08),
        border: Border.all(color: const Color.fromRGBO(240, 78, 106, 0.25)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _error!,
        style: AppFonts.body(size: 14, color: AppColors.danger),
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCityHero(),
        const SizedBox(height: 14),
        _buildWeatherCard(),
        const SizedBox(height: 14),
        _buildStatsGrid3(),
        const SizedBox(height: 14),
        _buildStatsGrid2(),
        const SizedBox(height: 14),
        _buildAQICard(),
        const SizedBox(height: 28),
        _buildActivities(),
        const SizedBox(height: 28),
        _buildPrecautions(),
        const SizedBox(height: 36),
        _buildLeavingNowButton(),
        const SizedBox(height: 36),
        _buildFooter(),
      ],
    );
  }

  Widget _buildCityHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _weather!.city,
          style: AppFonts.display(size: 48),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              _weather!.country,
              style: AppFonts.body(size: 12, color: const Color.fromRGBO(240, 237, 232, 0.80)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(240, 237, 232, 0.55),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _weather!.localTime.toString().substring(11, 16),
              style: AppFonts.body(size: 12, color: const Color.fromRGBO(240, 237, 232, 0.80)),
            ),
            const SizedBox(width: 8),
            Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Color.fromRGBO(240, 237, 232, 0.55),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_weather!.lat.toStringAsFixed(2)}°, ${_weather!.lon.toStringAsFixed(2)}°',
              style: AppFonts.body(size: 12, color: const Color.fromRGBO(240, 237, 232, 0.80)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeatherCard() {
    final temp = _formatTemp(_weather!.temp);
    final feelsLike = _formatTemp(_weather!.feelsLike);
    final sym = _getSym();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$temp°',
                  style: AppFonts.display(size: 64),
                ),
                Text(
                  _weather!.description,
                  style: AppFonts.body(
                    size: 17,
                    color: const Color.fromRGBO(240, 237, 232, 0.80),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Feels like $feelsLike$sym',
                  style: AppFonts.body(size: 14, color: const Color.fromRGBO(240, 237, 232, 0.65)),
                ),
                const SizedBox(height: 6),
                Text(
                  "Your skin doesn't do facts, only vibes.",
                  style: AppFonts.body(
                    size: 13,
                    color: const Color.fromRGBO(240, 237, 232, 0.72),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          WeatherIcon(code: _weather!.weatherCode, size: 90),
        ],
      ),
    );
  }

  Widget _buildStatsGrid3() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Humidity',
            '${_weather!.humidity}%',
            "How sweaty the air is. At 90%, you're not walking — you're wading.",
            "Humidity is the amount of water vapour in the air. Below 30% feels crispy-dry. 60–80% is that sticky, muggy feeling. Above 90%, sweat stops evaporating — your body's cooling system basically gives up.",
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            'Wind Speed',
            '${_weather!.windSpeed.toStringAsFixed(1)} m/s',
            "How fast the air is speed-running past your face right now.",
            "Wind speed in metres per second. Under 3 m/s is a gentle breeze. 8–10 m/s starts messing with umbrellas and hairstyles. Above 15 m/s? Loose objects become projectiles.",
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildStatCard(
            'Visibility',
            '${(_weather!.visibility / 1000).toStringAsFixed(1)} km',
            "How far you can see before the world goes blurry. Low? Maybe don't speed.",
            "Visibility in km. 10 km is a clear day. Below 4 km means haze or fog is building up. Below 1 km is when pilots decline invitations and drivers should slow way down.",
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid2() {
    final uv = estimateUV(_weather!.weatherCode, _weather!.temp);
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Pressure',
            '${_weather!.pressure} hPa',
            "The entire atmosphere sitting on everything. Your joints might disagree.",
            'Normal is ~1013 hPa. Dropping pressure = rain coming. Rising = clearer skies. Sharp drops = why your knees "know" when storms are coming.',
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('UV Index', style: AppFonts.label()),
                    _infoButton(
                      'UV Index',
                      'UV Index: 0–2 safe. 3–5 wear sunscreen. 6–7 SPF is non-negotiable. 8+ and the sun has decided to take things personally — hat, shade, and SPF 50+.',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "The sun's current mood. High UV = the sun is taking things personally.",
                  style: AppFonts.body(
                    size: 13,
                    color: const Color.fromRGBO(240, 237, 232, 0.72),
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 12),
                Text(
                  uv.val,
                  style: AppFonts.display(size: 28),
                ),
                Text(
                  uv.label,
                  style: AppFonts.body(size: 14, color: const Color.fromRGBO(240, 237, 232, 0.65)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String pun, String tooltip) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppFonts.label()),
              _infoButton(label, tooltip),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            pun,
            style: AppFonts.body(
              size: 13,
              color: const Color.fromRGBO(240, 237, 232, 0.72),
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppFonts.display(size: 28),
          ),
        ],
      ),
    );
  }

  Widget _infoButton(String title, String body) {
    return GestureDetector(
      onTap: () => _showInfoSheet(title, body),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            'i',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              fontFamily: 'serif',
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16161f),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1))),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title.toUpperCase(), style: AppFonts.label(size: 10)),
            const SizedBox(height: 10),
            Text(body, style: AppFonts.body(size: 15)),
          ],
        ),
      ),
    );
  }


  Widget _buildAQICard() {
    if (_aqi == null) {
      return Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppColors.cardTint,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Air Quality Index', style: AppFonts.label()),
                _infoButton(
                  'AQI',
                  "AQI runs 0–300+. Under 50 means the air is basically chef's kiss. 51–100 is fine for most. 101–150 starts affecting sensitive folks. Above 200 is when your lungs file formal complaints.",
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Like a restaurant rating — but for your lungs. 0 = Michelin star. 300 = just order in.",
              style: AppFonts.body(
                size: 13,
                color: const Color.fromRGBO(240, 237, 232, 0.72),
              ).copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            Text('?', style: AppFonts.display(size: 64)),
            Text(
              'No AQI data for this city.',
              style: AppFonts.body(size: 14, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final aqiInfo = getAQIInfo(_aqi!.aqi);

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.cardTint,
        border: Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Air Quality Index', style: AppFonts.label()),
                        const SizedBox(width: 8),
                        _infoButton(
                          'AQI',
                          "AQI runs 0–300+. Under 50 means the air is basically chef's kiss. 51–100 is fine for most. 101–150 starts affecting sensitive folks. Above 200 is when your lungs file formal complaints.",
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Like a restaurant rating — but for your lungs. 0 = Michelin star. 300 = just order in.",
                      style: AppFonts.body(
                        size: 13,
                        color: const Color.fromRGBO(240, 237, 232, 0.72),
                      ).copyWith(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_aqi!.aqi}',
                      style: AppFonts.display(size: 64),
                    ),
                    if (_aqi!.stationName != null)
                      Text(
                        _aqi!.stationName!,
                        style: AppFonts.body(size: 14, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: aqiInfo.bgColor,
                  border: Border.all(color: aqiInfo.dotColor.withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: aqiInfo.dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      aqiInfo.label,
                      style: AppFonts.body(
                        size: 11,
                        weight: FontWeight.w700,
                        color: aqiInfo.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_aqi!.iaqi != null) _buildPollutants(),
          const SizedBox(height: 16),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(100),
            ),
            child: FractionallySizedBox(
              widthFactor: (_aqi!.aqi / 300).clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: aqiInfo.color,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPollutants() {
    final pollutants = _aqi!.iaqi!;
    final pollKeys = ['pm25', 'pm10', 'o3', 'no2', 'so2', 'co'];
    final pollNames = {
      'pm25': 'PM2.5',
      'pm10': 'PM10',
      'o3': 'O₃',
      'no2': 'NO₂',
      'so2': 'SO₂',
      'co': 'CO',
    };
    final pollPuns = {
      'pm25': 'Tiny particles crashing your lungs uninvited. Absolute audacity.',
      'pm10': 'Bigger dust. Still rude. The annoying older sibling of PM2.5.',
      'o3': 'Ground-level ozone. Not the good kind. The kind your throat notices.',
      'no2': "Traffic's gift to your airways. You're welcome, said no one.",
      'so2': 'Industrial flavour in your air. Pairs poorly with breathing.',
      'co': 'Colourless, odourless, and deeply impolite. Classic CO.',
    };
    final pollTips = {
      'pm25': 'PM2.5 are fine particles smaller than 2.5 micrometres — they penetrate deep into lungs. Below 12 is good. Above 35 starts causing health effects.',
      'pm10': 'PM10 are coarser particles up to 10 micrometres. Below 54 is acceptable. Above 155 is unhealthy.',
      'o3': 'Ground-level ozone forms when sunlight reacts with pollutants. Below 54 ppb is good. Above 70 triggers health warnings.',
      'no2': 'Nitrogen dioxide mainly comes from vehicle engines. High levels irritate airways. Below 53 ppb is safe.',
      'so2': 'Sulphur dioxide comes from burning fossil fuels. High short exposures can harm the respiratory system. Below 35 ppb is good.',
      'co': 'Carbon monoxide from incomplete combustion. At high levels it interferes with oxygen delivery. Below 4.4 ppm is safe.',
    };

    final availablePollutants = <Widget>[];
    for (final k in pollKeys) {
      if (pollutants[k] != null && pollutants[k]['v'] != null) {
        availablePollutants.add(
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardTint,
                border: Border.all(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(pollNames[k]!, style: AppFonts.label(size: 9)),
                      _infoButton(pollNames[k]!, pollTips[k]!),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pollPuns[k]!,
                    style: AppFonts.body(
                      size: 11,
                      color: const Color.fromRGBO(240, 237, 232, 0.72),
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${pollutants[k]['v']}',
                    style: AppFonts.display(size: 22),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (availablePollutants.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: availablePollutants,
    );
  }

  Widget _buildActivities() {
    final activities = getActivities(
      _weather!.temp,
      _weather!.humidity,
      _weather!.windSpeed,
      _aqi?.aqi,
      _weather!.weatherCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECOMMENDED ACTIVITIES', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Text(
            'No specific recommendations for current conditions.',
            style: AppFonts.body(size: 14, color: AppColors.muted),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activities.map((a) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.cardTint,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a['icon'] as IconData, size: 20, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a['name'] as String,
                          style: AppFonts.body(size: 14, weight: FontWeight.w500),
                        ),
                        Text(
                          a['note'] as String,
                          style: AppFonts.body(size: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPrecautions() {
    final precautions = getPrecautions(
      _weather!.temp,
      _weather!.humidity,
      _weather!.windSpeed,
      _aqi?.aqi,
      _weather!.weatherCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PRECAUTIONS', style: AppFonts.label(size: 10)),
        const SizedBox(height: 12),
        ...precautions.map((p) {
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardTint,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 17,
                    color: p['color'] as Color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    p['text'] as String,
                    style: AppFonts.body(size: 14),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLeavingNowButton() {
    return GestureDetector(
      onTap: _showLeavingNow,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(200, 240, 78, 0.07),
          border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.28)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward_ios, size: 15, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              'Leaving now',
              style: AppFonts.body(
                size: 14,
                weight: FontWeight.w700,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeavingNow() {
    if (_weather == null) return;
    final outfit = getOutfit(
      _weather!.temp,
      _weather!.humidity,
      _weather!.windSpeed,
      _weather!.weatherCode,
    );
    final needsUmbrella = _weather!.weatherCode >= 300 && _weather!.weatherCode < 700;
    final aqiNum = _aqi?.aqi;
    final needsMask = aqiNum != null && aqiNum > 150;
    final visNum = _weather!.visibility / 1000;
    final visWarn = visNum < 4;
    final sym = _getSym();
    final tempV = _formatTemp(_weather!.temp);
    final feelsV = _formatTemp(_weather!.feelsLike);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF13131c),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color.fromRGBO(200, 240, 78, 0.14))),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 52),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Leaving now?', style: AppFonts.display(size: 24)),
            const SizedBox(height: 4),
            Text(
              '${_weather!.city}, ${_weather!.country} · $tempV$sym · ${_weather!.description}',
              style: AppFonts.body(size: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 22),
            _buildLeavingNowRow(outfit.emoji, 'What to wear', outfit.headline, outfit.tags.join(' · ')),
            _buildLeavingNowRow(
              needsUmbrella ? '☂️' : '🌤️',
              'Umbrella?',
              needsUmbrella ? 'Yes, take one.' : "Nope, you're good.",
              needsUmbrella ? 'Rain or drizzle expected.' : 'Skies are clear enough.',
            ),
            _buildLeavingNowRow(
              needsMask ? '😷' : '😮‍💨',
              'Air quality',
              needsMask ? 'Wear a mask.' : (aqiNum != null ? 'AQI $aqiNum — breathable.' : 'No AQI data.'),
              needsMask ? 'AQI above 150. Sensitive groups must cover up.' : '',
            ),
            _buildLeavingNowRow('🌡️', 'Feels like', '$feelsV$sym', 'Actual $tempV$sym · Humidity ${_weather!.humidity}%'),
            _buildLeavingNowRow(
              visWarn ? '🌫️' : '👁️',
              'Visibility',
              '${visNum.toStringAsFixed(1)} km',
              visWarn ? 'Low visibility — drive carefully.' : 'Clear enough to go.',
            ),
            _buildLeavingNowRow(
              _weather!.windSpeed > 8 ? '💨' : '🍃',
              'Wind',
              '${_weather!.windSpeed} m/s',
              _weather!.windSpeed > 10
                  ? 'Strong gusts. Secure loose items.'
                  : _weather!.windSpeed > 8
                      ? 'Noticeable wind.'
                      : 'Calm conditions.',
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(200, 240, 78, 0.09),
                  border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.22)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: Text(
                    'Back to full view',
                    style: AppFonts.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeavingNowRow(String emoji, String label, String value, String note) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
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

  const SettingsSheet({
    super.key,
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
        color: Color(0xFF111118),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.09))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 52),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text('Settings', style: AppFonts.display(size: 24)),
          const SizedBox(height: 6),
          Text(
            'Manage your Sylph preferences, history & data.',
            style: AppFonts.body(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 26),
          _buildSection('Personalisation', [
            _buildSettingsRow(
              'Your Name',
              widget.prefs['userName'] != null
                  ? 'Hi, ${widget.prefs['userName']}!'
                  : 'Used for your greeting.',
              'Change',
              true,
              () => _changeName(),
            ),
            _buildSettingsRow(
              'Home City',
              widget.prefs['homeCity'] != null
                  ? 'Currently set to: ${widget.prefs['homeCity']}'
                  : 'Auto-loads on startup & refreshes.',
              'Set',
              true,
              () => _changeHomeCity(),
            ),
          ]),
          _buildSection('Display', [
            _buildSettingsRow(
              'Temperature Unit',
              'Switch between Celsius and Fahrenheit.',
              '',
              false,
              null,
              trailing: Container(
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(100),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _settingsUnitButton('C'),
                    _settingsUnitButton('F'),
                  ],
                ),
              ),
            ),
          ]),
          _buildSection('Search History', [
            if (widget.history.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No searches yet.',
                  style: AppFonts.body(size: 14, color: AppColors.muted).copyWith(fontStyle: FontStyle.italic),
                ),
              )
            else
              ...widget.history.asMap().entries.map((e) {
                final item = e.value;
                final date = '${item.timestamp.month}/${item.timestamp.day} ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';
                final tempDisplay = widget.currentUnit == 'F'
                    ? '${toF(item.tempC)}°F'
                    : '${item.tempC.round()}°C';
                return GestureDetector(
                  onTap: () {
                    widget.onLoadCity(item.city);
                    Navigator.pop(context);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 255, 255, 0.03),
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.city}${item.country.isNotEmpty ? ', ${item.country}' : ''}',
                                style: AppFonts.body(size: 14, weight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '$date · ${item.description}${item.aqiNum != null ? ' · AQI ${item.aqiNum}' : ''}',
                                style: AppFonts.body(size: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          tempDisplay,
                          style: AppFonts.display(size: 18),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final newHistory = List<HistoryItem>.from(widget.history);
                            newHistory.removeAt(e.key);
                            widget.onHistoryUpdate(newHistory);
                            setState(() {});
                          },
                          child: Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                widget.onHistoryUpdate([]);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(240, 78, 106, 0.09),
                  border: Border.all(color: const Color.fromRGBO(240, 78, 106, 0.3)),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Clear All History',
                  style: AppFonts.body(size: 13, color: AppColors.danger),
                ),
              ),
            ),
          ]),
          _buildSection('Data', [
            _buildSettingsRow(
              'Export History',
              'Download your search history as JSON.',
              'Export',
              true,
              () {},
            ),
            _buildSettingsRow(
              'Clear All Data',
              'Remove all stored history and preferences.',
              'Clear',
              true,
              () {
                widget.onPrefsUpdate({});
                widget.onHistoryUpdate([]);
                setState(() {});
              },
              isDanger: true,
            ),
          ]),
          _buildSection('About', [
            _buildSettingsRow(
              'Sylph Weather & Air',
              'Data: OpenWeatherMap · WAQI · Built by Vijayarka',
              '',
              false,
              null,
            ),
          ]),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(200, 240, 78, 0.09),
                border: Border.all(color: const Color.fromRGBO(200, 240, 78, 0.22)),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Text(
                  'Done',
                  style: AppFonts.body(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Text(
            title.toUpperCase(),
            style: AppFonts.label(size: 10),
          ),
        ),
        ...children,
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _buildSettingsRow(
    String label,
    String sub,
    String btnText,
    bool hasButton,
    VoidCallback? onTap, {
    Widget? trailing,
    bool isDanger = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppFonts.body(size: 15)),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: AppFonts.body(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing
          else if (hasButton && onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isDanger
                      ? const Color.fromRGBO(240, 78, 106, 0.09)
                      : const Color.fromRGBO(200, 240, 78, 0.09),
                  border: Border.all(
                    color: isDanger
                        ? const Color.fromRGBO(240, 78, 106, 0.3)
                        : const Color.fromRGBO(200, 240, 78, 0.28),
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  btnText,
                  style: AppFonts.body(
                    size: 13,
                    color: isDanger ? AppColors.danger : AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingsUnitButton(String unit) {
    final isActive = widget.currentUnit == unit;
    return GestureDetector(
      onTap: () => widget.onUnitChange(unit),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '°$unit',
          style: AppFonts.body(
            size: 13,
            weight: FontWeight.w500,
            color: isActive ? AppColors.bg : AppColors.muted,
          ),
        ),
      ),
    );
  }

  void _changeName() {
    final controller = TextEditingController(text: widget.prefs['userName'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Your Name', style: AppFonts.display(size: 18)),
        content: TextField(
          controller: controller,
          style: AppFonts.body(),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: AppFonts.body(color: AppColors.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.body(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              final newPrefs = Map<String, dynamic>.from(widget.prefs);
              newPrefs['userName'] = controller.text.trim();
              widget.onPrefsUpdate(newPrefs);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Save', style: AppFonts.body(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _changeHomeCity() {
    final controller = TextEditingController(text: widget.prefs['homeCity'] ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Home City', style: AppFonts.display(size: 18)),
        content: TextField(
          controller: controller,
          style: AppFonts.body(),
          decoration: InputDecoration(
            hintText: 'e.g. Delhi, Tokyo, London…',
            hintStyle: AppFonts.body(color: AppColors.muted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.border),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppFonts.body(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              final newPrefs = Map<String, dynamic>.from(widget.prefs);
              newPrefs['homeCity'] = controller.text.trim();
              widget.onPrefsUpdate(newPrefs);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Save', style: AppFonts.body(color: AppColors.accent)),
          ),
        ],
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

  const OnboardingSheet({
    super.key,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF13131e),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.09))),
      ),
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'Syl', style: AppFonts.boldonse(size: 32)),
                TextSpan(text: 'ph', style: AppFonts.boldonse(size: 32, color: AppColors.accent)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Weather & air, with personality.',
            style: AppFonts.body(size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'WHAT SHOULD WE CALL YOU?',
              style: AppFonts.label(size: 11),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            style: AppFonts.body(),
            decoration: InputDecoration(
              hintText: 'Your name (optional)',
              hintStyle: AppFonts.body(color: AppColors.muted),
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent.withOpacity(0.4)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'YOUR HOME CITY (FOR LIVE UPDATES)',
              style: AppFonts.label(size: 11),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _cityController,
            style: AppFonts.body(),
            decoration: InputDecoration(
              hintText: 'e.g. Delhi, Tokyo, London…',
              hintStyle: AppFonts.body(color: AppColors.muted),
              filled: true,
              fillColor: const Color.fromRGBO(255, 255, 255, 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.accent.withOpacity(0.4)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              widget.onComplete(_nameController.text.trim(), _cityController.text.trim());
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Text(
                  "Let's go →",
                  style: AppFonts.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.bg,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              widget.onSkip();
              Navigator.pop(context);
            },
            child: Text(
              'Skip for now',
              style: AppFonts.body(size: 13, color: AppColors.muted).copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
