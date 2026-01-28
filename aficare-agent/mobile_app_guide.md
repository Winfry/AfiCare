# AfiCare MediLink Mobile App - Flutter + Supabase

## 🎯 **FREE Mobile App Architecture**

### **Option 2: Flutter + Supabase**
- **Cost:** $0 (Supabase free tier: 50,000 monthly active users)
- **Effort:** Medium
- **Timeline:** 4-6 weeks
- **Platforms:** iOS + Android + Web from single codebase

---

## 🏗️ **Architecture Overview**

```
📱 AfiCare MediLink Mobile App
├── 🎨 Flutter Frontend (Dart)
│   ├── Patient Dashboard
│   ├── Doctor Interface  
│   ├── Medical Consultations
│   ├── QR Code Sharing
│   └── Offline Sync
├── ☁️ Supabase Backend (PostgreSQL)
│   ├── Authentication (Magic Links, OAuth)
│   ├── Real-time Database
│   ├── Row Level Security
│   ├── Storage (Medical Images)
│   └── Edge Functions (Medical AI)
└── 🔄 Data Sync
    ├── SQLite (Local Storage)
    ├── Offline-First Architecture
    └── Background Sync
```

---

## 🚀 **Implementation Plan**

### **Phase 1: Setup & Foundation (Week 1)**

#### **1.1 Flutter Project Setup**
```bash
# Install Flutter
flutter doctor

# Create new project
flutter create aficare_mobile
cd aficare_mobile

# Add dependencies
flutter pub add supabase_flutter
flutter pub add sqflite
flutter pub add qr_flutter
flutter pub add qr_code_scanner
flutter pub add shared_preferences
flutter pub add connectivity_plus
```

#### **1.2 Supabase Setup**
```sql
-- Create tables in Supabase
CREATE TABLE patients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    medilink_id TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT,
    age INTEGER,
    gender TEXT,
    medical_history TEXT,
    allergies TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE consultations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    patient_id UUID REFERENCES patients(id),
    doctor_id UUID,
    symptoms TEXT[],
    vital_signs JSONB,
    diagnosis TEXT,
    treatment_plan TEXT,
    triage_level TEXT,
    consultation_date TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE access_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    patient_id UUID REFERENCES patients(id),
    access_code TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    used_by UUID,
    used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### **Phase 2: Core Features (Week 2-3)**

#### **2.1 Authentication System**
```dart
// lib/services/auth_service.dart
class AuthService {
  static final _supabase = Supabase.instance.client;
  
  // Patient registration with MediLink ID
  Future<AuthResponse> registerPatient({
    required String fullName,
    required String phone,
    required String email,
    required int age,
    required String gender,
  }) async {
    final medilinkId = generateMedilinkId();
    
    final response = await _supabase.auth.signUp(
      email: email,
      password: generateSecurePassword(),
      data: {
        'full_name': fullName,
        'phone': phone,
        'medilink_id': medilinkId,
        'role': 'patient',
        'age': age,
        'gender': gender,
      }
    );
    
    return response;
  }
  
  // Healthcare provider login
  Future<AuthResponse> loginProvider({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
}
```

#### **2.2 Patient Dashboard**
```dart
// lib/screens/patient_dashboard.dart
class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AfiCare MediLink'),
        backgroundColor: Color(0xFF2E8B57),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // MediLink ID Card
            _buildMedilinkCard(),
            SizedBox(height: 20),
            
            // Quick Actions
            _buildQuickActions(),
            SizedBox(height: 20),
            
            // Recent Consultations
            _buildRecentConsultations(),
            SizedBox(height: 20),
            
            // Health Summary
            _buildHealthSummary(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMedilinkCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Your MediLink ID', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(
              'ML-NBO-A1B2C3', 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
            ),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _generateQRCode,
              icon: Icon(Icons.qr_code),
              label: Text('Share with Doctor'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### **2.3 Medical AI Integration**
```dart
// lib/services/medical_ai_service.dart
class MedicalAIService {
  static final _supabase = Supabase.instance.client;
  
  Future<ConsultationResult> conductConsultation({
    required String patientId,
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
    required String gender,
  }) async {
    
    // Call Supabase Edge Function for medical analysis
    final response = await _supabase.functions.invoke(
      'medical-consultation',
      body: {
        'patient_id': patientId,
        'symptoms': symptoms,
        'vital_signs': vitalSigns,
        'age': age,
        'gender': gender,
      }
    );
    
    return ConsultationResult.fromJson(response.data);
  }
  
  Future<TriageResult> assessUrgency({
    required List<String> symptoms,
    required Map<String, double> vitalSigns,
    required int age,
  }) async {
    
    // Local triage assessment for offline capability
    double urgencyScore = 0.0;
    List<String> dangerSigns = [];
    
    // Check for emergency symptoms
    final emergencyKeywords = [
      'difficulty breathing', 'chest pain', 'unconscious',
      'severe bleeding', 'convulsions', 'severe headache'
    ];
    
    for (String symptom in symptoms) {
      for (String keyword in emergencyKeywords) {
        if (symptom.toLowerCase().contains(keyword)) {
          urgencyScore += 1.0;
          dangerSigns.add(keyword);
        }
      }
    }
    
    // Check vital signs
    final temp = vitalSigns['temperature'] ?? 37.0;
    if (temp > 40.0 || temp < 35.0) {
      urgencyScore += 0.8;
      dangerSigns.add('Critical temperature: ${temp}°C');
    }
    
    // Determine triage level
    String level;
    if (urgencyScore >= 0.8) {
      level = 'EMERGENCY';
    } else if (urgencyScore >= 0.5) {
      level = 'URGENT';
    } else if (urgencyScore >= 0.3) {
      level = 'LESS_URGENT';
    } else {
      level = 'NON_URGENT';
    }
    
    return TriageResult(
      level: level,
      score: urgencyScore,
      dangerSigns: dangerSigns,
      referralNeeded: urgencyScore >= 0.5,
    );
  }
}
```

### **Phase 3: Advanced Features (Week 4-5)**

#### **3.1 Offline Sync System**
```dart
// lib/services/sync_service.dart
class SyncService {
  static final _localDb = DatabaseHelper.instance;
  static final _supabase = Supabase.instance.client;
  
  Future<void> syncPatientData() async {
    try {
      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('No internet connection - working offline');
        return;
      }
      
      // Sync pending consultations
      await _syncPendingConsultations();
      
      // Download latest patient data
      await _downloadPatientUpdates();
      
      // Upload local changes
      await _uploadLocalChanges();
      
    } catch (e) {
      print('Sync error: $e');
    }
  }
  
  Future<void> _syncPendingConsultations() async {
    final pendingConsultations = await _localDb.getPendingConsultations();
    
    for (final consultation in pendingConsultations) {
      try {
        await _supabase.from('consultations').insert(consultation.toJson());
        await _localDb.markConsultationSynced(consultation.id);
      } catch (e) {
        print('Failed to sync consultation ${consultation.id}: $e');
      }
    }
  }
}
```

#### **3.2 QR Code Sharing**
```dart
// lib/screens/qr_share_screen.dart
class QRShareScreen extends StatelessWidget {
  final String medilinkId;
  final String accessCode;
  
  QRShareScreen({required this.medilinkId, required this.accessCode});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Medical Records'),
        backgroundColor: Color(0xFF2E8B57),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show this QR code to your doctor',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            
            // QR Code
            QrImage(
              data: jsonEncode({
                'medilink_id': medilinkId,
                'access_code': accessCode,
                'expires_at': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
              }),
              version: QrVersions.auto,
              size: 200.0,
            ),
            
            SizedBox(height: 30),
            
            // Access Code Display
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Access Code:', style: TextStyle(fontSize: 16)),
                    SizedBox(height: 8),
                    Text(
                      accessCode,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Valid for 1 hour',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: () => _shareAccessCode(context),
              child: Text('Share Access Code'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _shareAccessCode(BuildContext context) {
    Share.share(
      'My AfiCare MediLink ID: $medilinkId\nAccess Code: $accessCode\nValid for 1 hour',
      subject: 'AfiCare Medical Records Access',
    );
  }
}
```

### **Phase 4: Production Ready (Week 6)**

#### **4.1 App Store Preparation**
```yaml
# pubspec.yaml
name: aficare_medilink
description: AI-Powered Patient Records for African Healthcare
version: 1.0.0+1

flutter:
  uses-material-design: true
  assets:
    - assets/images/
    - assets/icons/
  
  # App icons
  flutter_icons:
    android: true
    ios: true
    image_path: "assets/icons/app_icon.png"
    adaptive_icon_background: "#2E8B57"
    adaptive_icon_foreground: "assets/icons/app_icon_foreground.png"
```

#### **4.2 Supabase Edge Functions**
```typescript
// supabase/functions/medical-consultation/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const { patient_id, symptoms, vital_signs, age, gender } = await req.json()
    
    // Medical AI logic (simplified)
    const consultationResult = await conductMedicalAnalysis({
      symptoms,
      vital_signs,
      age,
      gender
    })
    
    // Save consultation to database
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    const { data, error } = await supabase
      .from('consultations')
      .insert({
        patient_id,
        symptoms,
        vital_signs,
        diagnosis: consultationResult.diagnosis,
        treatment_plan: consultationResult.treatment,
        triage_level: consultationResult.triage_level,
      })
    
    return new Response(
      JSON.stringify({ success: true, result: consultationResult }),
      { headers: { "Content-Type": "application/json" } }
    )
    
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    )
  }
})
```

---

## 💰 **Cost Breakdown (FREE)**

### **Supabase Free Tier Limits:**
- ✅ **50,000 monthly active users**
- ✅ **500MB database storage**
- ✅ **1GB file storage**
- ✅ **2 million Edge Function invocations**
- ✅ **Unlimited API requests**
- ✅ **Real-time subscriptions**

### **Flutter Development:**
- ✅ **Flutter SDK: FREE**
- ✅ **Android Studio: FREE**
- ✅ **VS Code: FREE**
- ✅ **Google Play Console: $25 one-time**
- ✅ **Apple Developer: $99/year (optional)**

**Total Cost: $0-$124/year** (depending on iOS deployment)

---

## 🚀 **Getting Started Commands**

```bash
# 1. Install Flutter
git clone https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"
flutter doctor

# 2. Create project
flutter create aficare_mobile
cd aficare_mobile

# 3. Add dependencies
flutter pub add supabase_flutter sqflite qr_flutter qr_code_scanner

# 4. Run on device
flutter run

# 5. Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

---

## 📱 **App Features**

### **Patient Features:**
- ✅ MediLink ID management
- ✅ QR code sharing with doctors
- ✅ Medical history tracking
- ✅ Consultation history
- ✅ Offline access to records
- ✅ Emergency contact integration

### **Healthcare Provider Features:**
- ✅ QR code scanner for patient access
- ✅ Medical consultation interface
- ✅ AI-powered diagnosis assistance
- ✅ Triage assessment
- ✅ Treatment recommendations
- ✅ Patient search and access

### **Technical Features:**
- ✅ Offline-first architecture
- ✅ Real-time data sync
- ✅ End-to-end encryption
- ✅ Multi-language support
- ✅ Cross-platform compatibility
- ✅ Progressive Web App support

---

## 🎯 **Next Steps**

1. **Set up Supabase account** (free)
2. **Install Flutter development environment**
3. **Create the mobile app project**
4. **Implement core features**
5. **Test with existing web app data**
6. **Deploy to app stores**

Would you like me to start implementing any specific part of this mobile app architecture?