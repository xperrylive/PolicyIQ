# 🎨 Flutter Frontend Deployment Guide
## PolicyIQ Dashboard Configuration

This guide helps you configure and deploy the PolicyIQ Flutter frontend for the hackathon demo.

---

## 🔧 Configuration

### Step 1: Update API Base URL

Open `lib/services/api_client.dart` and update the base URL:

```dart
// BEFORE (local development)
const String _kApiBaseUrl = 'http://127.0.0.1:8000';

// AFTER (Cloud Run deployment)
const String _kApiBaseUrl = 'https://policyiq-backend-v6fp4t7mca-as.a.run.app';
```

**Important**: This URL is now set to the live production backend.

### Step 2: Verify CORS Configuration

The backend is already configured to allow all origins for the hackathon:

```python
# backend/main.py (already configured)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows Flutter web app to connect
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

No changes needed on the Flutter side!

---

## 🚀 Build & Deploy

### Option 1: Web Deployment (Recommended for Hackathon)

#### Build for Web
```bash
cd frontend
flutter clean
flutter pub get
flutter build web --release
```

#### Deploy to Firebase Hosting (Optional)
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in the frontend directory
firebase init hosting

# Select options:
# - Public directory: build/web
# - Single-page app: Yes
# - Automatic builds: No

# Deploy
firebase deploy --only hosting
```

Your Flutter app will be live at: `https://your-project.web.app`

#### Deploy to GitHub Pages (Alternative)
```bash
# Build for web
flutter build web --release --base-href "/PolicyIQ/"

# Copy build to docs folder (for GitHub Pages)
cp -r build/web ../docs

# Commit and push
git add docs
git commit -m "Deploy Flutter web app"
git push

# Enable GitHub Pages in repository settings:
# Settings → Pages → Source: main branch /docs folder
```

Your Flutter app will be live at: `https://your-username.github.io/PolicyIQ/`

### Option 2: Windows Desktop App

```bash
cd frontend
flutter clean
flutter pub get
flutter build windows --release
```

Executable location: `build/windows/runner/Release/policy_iq.exe`

**Distribution**:
1. Zip the entire `Release` folder
2. Share with judges via Google Drive / Dropbox
3. Include instructions: "Extract and run policy_iq.exe"

### Option 3: macOS Desktop App

```bash
cd frontend
flutter clean
flutter pub get
flutter build macos --release
```

App location: `build/macos/Build/Products/Release/policy_iq.app`

**Distribution**:
1. Zip the `.app` file
2. Share with judges
3. Note: May require "Open Anyway" in System Preferences → Security

---

## 🧪 Testing Your Deployment

### Test 1: Connection to Backend
```bash
# Start the Flutter app
flutter run -d chrome

# In the Gatekeeper screen, enter:
"Test connection to backend"

# Click "Validate Policy"
# Expected: Response from Cloud Run backend
```

### Test 2: Full Simulation
```bash
# In the Gatekeeper screen, enter:
"Increase RON95 petrol price to RM3.35/litre"

# Click "Validate Policy"
# Expected: is_feasible = true, Environment Blueprint generated

# Click "Run Simulation"
# Expected: Real-time SSE stream, dashboard updates
```

### Test 3: Cross-Platform
```bash
# Test on multiple platforms
flutter run -d chrome      # Web
flutter run -d windows     # Windows (if on Windows)
flutter run -d macos       # macOS (if on macOS)
```

---

## 🎨 UI Configuration

### Theme Customization (Optional)

If you want to customize the theme for the hackathon demo:

```dart
// lib/theme/app_theme.dart
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Color(0xFF1E88E5),  // Change primary color
      scaffoldBackgroundColor: Color(0xFF121212),
      // ... other theme properties
    );
  }
}
```

### Logo & Branding (Optional)

Add your hackathon logo:
1. Place logo in `assets/images/logo.png`
2. Update `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/images/logo.png
   ```
3. Use in app:
   ```dart
   Image.asset('assets/images/logo.png', height: 50)
   ```

---

## 🔒 Security Notes

### For Hackathon Demo
- API base URL is hardcoded (fine for demo)
- No authentication required (backend is `--allow-unauthenticated`)
- CORS allows all origins

### For Production (Post-Hackathon)
If you continue this project:

1. **Environment Variables**:
   ```dart
   // Use flutter_dotenv for environment-specific URLs
   const String _kApiBaseUrl = String.fromEnvironment(
     'API_BASE_URL',
     defaultValue: 'http://127.0.0.1:8000',
   );
   ```

2. **Authentication**:
   ```dart
   // Add API key header
   final response = await _httpClient.post(
     uri,
     headers: {
       'Content-Type': 'application/json',
       'X-API-Key': apiKey,  // Add authentication
     },
   );
   ```

3. **Error Handling**:
   ```dart
   // Add retry logic for network failures
   try {
     final response = await _httpClient.post(uri);
   } on SocketException {
     // Retry after 2 seconds
     await Future.delayed(Duration(seconds: 2));
     final response = await _httpClient.post(uri);
   }
   ```

---

## 📊 Performance Optimization

### Web Performance
```bash
# Enable web renderer optimization
flutter build web --release --web-renderer canvaskit

# For better initial load time (use HTML renderer)
flutter build web --release --web-renderer html
```

### Desktop Performance
```bash
# Enable tree-shake-icons to reduce bundle size
flutter build windows --release --tree-shake-icons
flutter build macos --release --tree-shake-icons
```

---

## 🐛 Troubleshooting

### Issue: "Backend is unreachable"
**Solution**:
1. Verify Cloud Run URL is correct in `api_client.dart`
2. Test backend health: `curl https://your-cloud-run-url/health`
3. Check browser console for CORS errors
4. Ensure backend is running: `gcloud run services list`

### Issue: "CORS policy blocked"
**Solution**:
1. Verify backend CORS is set to `allow_origins=["*"]`
2. Check backend logs: `gcloud run logs read policyiq-backend`
3. Test with curl: `curl -I -X OPTIONS https://your-cloud-run-url/validate-policy`

### Issue: "SSE stream not updating"
**Solution**:
1. Check browser console for SSE errors
2. Verify `/simulate` endpoint is working: Test in API docs
3. Ensure Flutter SSE client is handling events correctly
4. Check backend logs for simulation errors

### Issue: "Flutter build fails"
**Solution**:
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter pub upgrade
flutter build web --release
```

---

## 📦 Distribution Checklist

### For Web Deployment
- [ ] Updated `_kApiBaseUrl` to Cloud Run URL
- [ ] Built with `flutter build web --release`
- [ ] Tested in Chrome, Firefox, Safari
- [ ] Deployed to Firebase Hosting / GitHub Pages
- [ ] Shared live URL with judges

### For Desktop Deployment
- [ ] Updated `_kApiBaseUrl` to Cloud Run URL
- [ ] Built with `flutter build windows/macos --release`
- [ ] Tested executable on target platform
- [ ] Zipped release folder
- [ ] Uploaded to Google Drive / Dropbox
- [ ] Shared download link with judges

---

## 🎯 Demo Preparation

### Pre-Demo Checklist
- [ ] Backend is running on Cloud Run
- [ ] Frontend is deployed (web or desktop)
- [ ] Test all 3 sample policies
- [ ] Verify real-time SSE updates work
- [ ] Check that charts render correctly
- [ ] Ensure anomaly hunter displays breaking points

### Demo Script
1. **Introduction** (30s): "PolicyIQ is SimCity for Malaysian government policy..."
2. **Gatekeeper** (1m): Show rejection + 3 alternatives
3. **Advisor** (1m): Show Environment Blueprint with 8 knobs
4. **Dashboard** (2m): Run live simulation, show real-time updates
5. **Verdict** (1m): Show AI recommendation + export report
6. **Closing** (30s): "Impacting 34 million Malaysians..."

---

## 📞 Support

For Flutter-specific issues:
1. Check Flutter doctor: `flutter doctor -v`
2. Review build logs: `flutter build web --verbose`
3. Test on different platforms
4. Check Flutter version: `flutter --version` (should be ≥3.19)

---

**Good luck with your hackathon demo! 🚀**
