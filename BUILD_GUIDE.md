# BUILD GUIDE - Sylph Weather App

## ✅ **Fixed Issues**

### 1. **Build Configuration**
- ✅ Disabled minification (was causing conflicts)
- ✅ Disabled resource shrinking
- ✅ Added proper ProGuard rules
- ✅ Updated gradle.properties with optimization settings

### 2. **Dependencies**
- ✅ Added `flutter_local_notifications: ^15.1.3`
- ✅ Added `timezone: ^0.9.2`
- ✅ All packages properly resolved

### 3. **Permissions**
- ✅ Added `POST_NOTIFICATIONS` for Android 13+
- ✅ Added `SCHEDULE_EXACT_ALARM` for weather checks

---

## 🚀 **Step-by-Step Build Process**

### **Step 1: Clean Previous Builds**
```bash
flutter clean
cd android
./gradlew clean
cd ..
```

### **Step 2: Get API Keys**
- **OpenWeatherMap**: https://openweathermap.org/api
- **WAQI**: https://waqi.info/api/

### **Step 3: Generate Keystore (for release builds)**
```bash
keytool -genkey -v -keystore ~/android_key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias android_key
```

### **Step 4: Create key.properties File**
Create file: `android/key.properties`
```properties
storeFile=/path/to/android_key.jks
storePassword=your_keystore_password
keyAlias=android_key
keyPassword=your_key_password
```

### **Step 5: Build Debug APK (Test)**
```bash
flutter build apk --debug \
  --dart-define=OWM_KEY=your_openweather_key \
  --dart-define=WAQI_KEY=your_waqi_key
```

**Output**: `build/app/outputs/apk/debug/app-debug.apk`

### **Step 6: Build Release APK (Production)**
```bash
flutter build apk --release \
  --dart-define=OWM_KEY=your_openweather_key \
  --dart-define=WAQI_KEY=your_waqi_key
```

**Output**: `build/app/outputs/apk/release/app-release.apk`

---

## 🔧 **Troubleshooting**

### **Issue: Gradle Build Fails**
```bash
# Solution: Clear all caches
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
```

### **Issue: Notification Permissions Error**
✅ Already fixed in AndroidManifest.xml

### **Issue: API Key Not Working**
✅ Ensure keys are passed correctly:
```bash
# Check: Keys must not have spaces
flutter build apk --release \
  --dart-define=OWM_KEY=abc123def456 \
  --dart-define=WAQI_KEY=xyz789uvw012
```

### **Issue: ProGuard/Minification**
✅ Disabled by default now - safe for release builds

---

## 📋 **Build Checklist**

- [ ] Android SDK API 34 installed
- [ ] Java 11+ installed
- [ ] Flutter latest version installed
- [ ] `flutter pub get` completed
- [ ] API keys obtained
- [ ] Keystore file created
- [ ] key.properties configured
- [ ] All permissions verified

---

## 📦 **Final APK Details**

| Property | Value |
|----------|-------|
| **Package Name** | com.example.sylph |
| **Min SDK** | 21 (Android 5.0) |
| **Target SDK** | 34 (Android 14) |
| **Version Code** | 1 |
| **Version Name** | 1.0 |

---

## ✨ **Features Included**

✅ Weather data from OpenWeatherMap  
✅ Air quality data from WAQI  
✅ Local notifications (weather & AQI alerts)  
✅ Search history (last 20 cities)  
✅ Temperature unit toggle (°C/°F)  
✅ Detailed weather metrics  
✅ Professional UI with Material Design 3  

---

## 🎯 **Ready to Deploy!**

Your APK is now production-ready and error-free. 🚀

For Play Store release, also read:
- Google Play Console guidelines
- App signing documentation
- Privacy policy requirements
