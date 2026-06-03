# 🧺 Flutter Laundry Finder - 4 Fitur Baru (Complete Implementation Guide)

**Panduan lengkap menambahkan 4 fitur baru ke aplikasi Flutter Laundry Finder Anda dengan mempertahankan struktur single `main.dart`.**

---

## 📚 Dokumentasi Tersedia

Kami menyediakan 3 file dokumentasi untuk memudahkan implementasi:

### 1. **FLUTTER_IMPLEMENTATION_GUIDE.md** 
   📖 Panduan lengkap step-by-step dengan penjelasan detail setiap fitur.
   - Best untuk: Pemahaman mendalam tentang setiap feature
   - Target: Developers yang ingin mengerti logika di balik setiap kode

### 2. **FLUTTER_CODE_SNIPPETS.dart**
   💻 Copy-paste code snippets yang siap digunakan.
   - Best untuk: Implementasi cepat
   - Target: Developers yang langsung ingin implementasi kode

### 3. **PLACEMENT_GUIDE.md**
   🎯 Visual guide penempatan setiap kode dalam struktur main.dart.
   - Best untuk: Tahu persis di mana memasukkan setiap kode
   - Target: Developers yang tidak ingin ketinggalan line number

### 4. **pubspec_updated.yaml**
   📦 File pubspec.yaml yang sudah diupdate dengan dependencies baru.
   - Copy ke project Anda dan jalankan `flutter pub get`

---

## 🎯 OVERVIEW: 4 FITUR BARU

### ✨ Feature 1: TAMPILKAN JARAK KE LAUNDRY
**Status Implementasi:** Support HomeScreen, DirectoryScreen, PlaceDetailScreen

Aplikasi menghitung jarak real-time antara lokasi user dan laundry menggunakan Geolocator.

- 📍 **Tampilan Jarak:**
  - < 1000 meter → `250 m`
  - ≥ 1000 meter → `1.5 km`
- ⏳ **Loading State:** `Menghitung jarak...` (hingga lokasi tersedia)
- 🗺️ **Lokasi:**
  - HomeScreen: Di setiap card laundry
  - DirectoryScreen: Di setiap card laundry
  - PlaceDetailScreen: Di bawah alamat

---

### ❤️ Feature 2: FAVORITE LAUNDRY
**Status Implementasi:** HomeScreen, DirectoryScreen, PlaceDetailScreen

Gunakan SharedPreferences untuk menyimpan daftar laundry favorit.

- 💾 **Penyimpanan:** SharedPreferences (persistent, tetap ada setelah app tutup)
- 🏠 **HomeScreen:** Menampilkan section "Laundry Favorit" di atas daftar semua laundry
- ❌ **Fallback:** "Belum ada laundry favorit" jika list kosong
- ❤️ **Icon:**
  - `Icons.favorite_border` (belum favorit)
  - `Icons.favorite` (sudah favorit, warna merah)

---

### 🎯 Feature 3: FILTER BERDASARKAN JARAK TERDEKAT
**Status Implementasi:** DirectoryScreen

Filter chip untuk mengurutkan laundry dari terdekat ke terjauh.

- 📊 **Filter Options:**
  - `Semua` (default, no sorting)
  - `Terdekat` (sort by distance ascending)
  - `Rating Tertinggi` (sort by rating descending)
- 🔄 **Re-calculation:** Jarak dihitung ulang setiap kali membuka DirectoryScreen
- 📱 **UI:** Horizontal scrollable chip buttons di bawah search bar

---

### ⭐ Feature 4: FILTER BERDASARKAN RATING
**Status Implementasi:** DirectoryScreen

Filter chip untuk mengurutkan laundry dari rating tertinggi.

- ⭐ **Rating Sort:** Descending (5.0 star paling atas)
- 🔗 **Kombinasi Filter:** Bisa dikombinasikan dengan kategori + search

---

## 🚀 QUICK START (3 STEPS)

### STEP 1: Update pubspec.yaml (5 menit)

```bash
# Copy file pubspec_updated.yaml ke project Anda
cp pubspec_updated.yaml pubspec.yaml

# Install dependencies
flutter pub get

# Untuk iOS
cd ios && pod install && cd ..
```

### STEP 2: Update main.dart (30 menit)

Ikuti **PLACEMENT_GUIDE.md** untuk tahu persis di mana menambahkan/mengubah kode.

Atau gunakan **FLUTTER_CODE_SNIPPETS.dart** untuk copy-paste langsung.

### STEP 3: Test (5 menit)

```bash
flutter clean
flutter run
```

Test 4 fitur:
- [ ] **Feature 1:** Lihat jarak muncul di card & detail screen
- [ ] **Feature 2:** Klik ❤️ icon → muncul di "Laundry Favorit" section
- [ ] **Feature 3:** DirectoryScreen → klik "Terdekat" → list tersort by distance
- [ ] **Feature 4:** DirectoryScreen → klik "Rating Tertinggi" → list tersort by rating

---

## 📝 DEPENDENCY SUMMARY

### Existing Dependencies (JANGAN DIUBAH)
```yaml
flutter_map: ^6.0.0       # Map OpenStreetMap
latlong2: ^0.8.1          # Koordinat LatLng
http: ^1.1.0              # HTTP client untuk GAS API
geolocator: ^9.0.2        # GPS & distance calculation
```

### New Dependencies (TAMBAHAN)
```yaml
shared_preferences: ^2.2.0  # ✅ Untuk Favorites storage
path_drawing: ^1.0.1        # ✅ Optional, untuk polyline styling
```

---

## 🔍 ARCHITECTURE OVERVIEW

### Services Layer
```
┌─────────────────────────────────────────┐
│         Services (main.dart)            │
├─────────────────────────────────────────┤
│ 1. ApiService                           │ → Fetch data dari GAS
│ 2. RoutingService (existing)            │ → OSRM rute
│ 3. FavoritesService (NEW)               │ → SharedPreferences
└─────────────────────────────────────────┘
```

### UI Layer
```
┌──────────────────────────────────────────────────────────┐
│                    Screens                               │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  HomeScreen                 DirectoryScreen             │
│  ├─ Jarak ✅ (NEW)          ├─ Jarak ✅ (NEW)           │
│  ├─ Favorit ✅ (NEW)        ├─ Favorit ✅ (NEW)        │
│  └─ _PlaceCard              ├─ Filter Jarak ✅ (NEW)   │
│     ├─ Distance calc        ├─ Filter Rating ✅ (NEW)  │
│     ├─ Favorite btn         └─ _PlaceCard              │
│     └─ Distance display                                 │
│                                                         │
│  PlaceDetailScreen                                      │
│  ├─ Distance ✅ (NEW)                                   │
│  ├─ Favorite button ✅ (NEW)                            │
│  └─ Route button (existing)                            │
└──────────────────────────────────────────────────────────┘
```

### Data Flow
```
┌─────────────────┐
│  API Service    │
│  (GAS + Sheets) │
└────────┬────────┘
         │
         ↓
┌─────────────────────┐
│   Place Models      │
│ (id, name, lat/lng) │
└────────┬────────────┘
         │
         ├──→ [Distance Calculation]  ← Geolocator
         ├──→ [Favorite Status Check] ← SharedPreferences
         ├──→ [Sorting Logic]         ← _applyFilter()
         │
         ↓
    [UI Display]
```

---

## 💡 KEY IMPLEMENTATION DETAILS

### 1. Distance Calculation
```dart
// Using Geolocator
double distance = Geolocator.distanceBetween(
  userLat, userLng,
  placeLat, placeLng,
);

// Format output
String distanceText = distance < 1000
  ? '${distance.toStringAsFixed(0)} m'
  : '${(distance / 1000).toStringAsFixed(1)} km';
```

### 2. Favorites Persistence
```dart
// Save
await FavoritesService.addFavorite(placeId);

// Check
bool isFav = await FavoritesService.isFavorite(placeId);

// Retrieve
List<int> favorites = await FavoritesService.getFavorites();
```

### 3. Sorting Logic
```dart
if (_sortFilter == 'nearest') {
  _filtered.sort((a, b) => distA.compareTo(distB));
} else if (_sortFilter == 'highest_rating') {
  _filtered.sort((a, b) => b.rating.compareTo(a.rating));
}
```

---

## 🐛 TROUBLESHOOTING GUIDE

| Problem | Cause | Solution |
|---------|-------|----------|
| Jarak tidak tampil | GPS tidak aktif | Nyalakan Location Service di settings |
| Permission denied | App tidak punya izin | Cek AndroidManifest.xml & Info.plist |
| Favorites tidak tersimpan | SharedPreferences error | `flutter pub get` & `flutter clean` |
| Filter tidak bekerja | _userLocation null | Pastikan _load() ambil lokasi |
| "Menghitung jarak..." stuck | Timeout GPS | Gunakan mock location di emulator |
| Build error | Missing imports | Pastikan semua imports sudah ditambahkan |
| Widget not found | Copy-paste error | Cek indentasi & bracket matching |

---

## 🧪 TESTING CHECKLIST

### Feature 1: Distance Display
- [ ] HomeScreen: Setiap card menampilkan jarak
- [ ] DirectoryScreen: Setiap card menampilkan jarak
- [ ] PlaceDetailScreen: Jarak muncul di bawah alamat
- [ ] Loading state: "Menghitung jarak..." muncul di awal
- [ ] Accuracy: Jarak terlihat reasonable (bukan 0 meter untuk semua)

### Feature 2: Favorites
- [ ] Icon berubah dari favorite_border → favorite (merah)
- [ ] HomeScreen: Section "Laundry Favorit" muncul dengan item favorit
- [ ] Data persisten: Close app → buka ulang → favorit masih ada
- [ ] Remove: Klik favorit lagi → hilang dari list
- [ ] Empty state: "Belum ada laundry favorit" muncul jika list kosong

### Feature 3: Distance Filter
- [ ] DirectoryScreen: "Terdekat" chip muncul
- [ ] Klik "Terdekat" → list sorted by distance (ascending)
- [ ] Klik "Semua" → kembali ke default order
- [ ] Kombinasi dengan search: Tetap sorted saat search

### Feature 4: Rating Filter
- [ ] DirectoryScreen: "Rating Tertinggi" chip muncul
- [ ] Klik "Rating Tertinggi" → list sorted by rating (descending, 5.0 paling atas)
- [ ] Klik "Semua" → kembali ke default order
- [ ] Kombinasi dengan kategori filter: Tetap berfungsi

---

## 📞 GETTING HELP

### Common Error Messages

**"The method 'FavoritesService' isn't defined"**
```
✅ Solution: Pastikan FavoritesService class sudah ditambahkan setelah ApiService
```

**"_distance is null"**
```
✅ Solution: Pastikan Geolocator.distanceBetween() dipanggil di initState()
```

**"_userLocation is null when sorting"**
```
✅ Solution: Pastikan _load() successfully retrieve user location sebelum _applyFilter()
```

**"pubspec.yaml error: dependency X not found"**
```
✅ Solution: flutter pub get && flutter pub cache clean
```

---

## ✅ FINAL CHECKLIST

### Before Implementation
- [ ] Backup current main.dart (rename to main.dart.bak)
- [ ] Read PLACEMENT_GUIDE.md completely
- [ ] Prepare all 3 files: GUIDE, SNIPPETS, PLACEMENT_GUIDE

### During Implementation
- [ ] Follow PLACEMENT_GUIDE.md step by step
- [ ] Copy code dari FLUTTER_CODE_SNIPPETS.dart
- [ ] Compile after each major change (test incrementally)
- [ ] Check error messages in logcat/console

### After Implementation
- [ ] `flutter clean`
- [ ] `flutter pub get`
- [ ] `flutter run`
- [ ] Test all 4 features
- [ ] Test on both iOS & Android if possible

### Quality Assurance
- [ ] No compiler errors
- [ ] All 4 features working
- [ ] No regressions in existing features
- [ ] Performance acceptable (no lag)
- [ ] Data persistence working (close/open app)

---

## 📚 REFERENCE LINKS

- [SharedPreferences Documentation](https://pub.dev/packages/shared_preferences)
- [Geolocator Documentation](https://pub.dev/packages/geolocator)
- [Flutter Documentation](https://flutter.dev)
- [Flutter Map Documentation](https://pub.dev/packages/flutter_map)

---

## 🎓 LEARNING RESOURCES

### StatefulWidget Conversion
```dart
// StatelessWidget → StatefulWidget
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    // Initialize
  }
  
  @override
  Widget build(BuildContext context) {
    // Build UI
  }
}
```

### Async/Await Pattern
```dart
Future<void> myAsyncFunction() async {
  try {
    final result = await someAsyncCall();
    setState(() => _data = result);
  } catch (e) {
    print('Error: $e');
  }
}
```

---

## 🎉 SELESAI!

Setelah mengikuti panduan ini, aplikasi Anda akan memiliki:
- ✅ **Jarak real-time** ke setiap laundry
- ✅ **Sistem Favorit** yang persistent
- ✅ **Filter Jarak** untuk find nearest laundry
- ✅ **Filter Rating** untuk find best rated laundry

**Total Lines Changed:** ~400-500 baris (masih dalam 1 file main.dart)
**Complexity Level:** Intermediate (requires StatefulWidget + async understanding)
**Estimated Time:** 30-60 menit untuk implementasi + 10 menit testing

---

**Semoga sukses! 🚀**

Jika ada pertanyaan, lihat TROUBLESHOOTING GUIDE atau cek logcat untuk error details.
