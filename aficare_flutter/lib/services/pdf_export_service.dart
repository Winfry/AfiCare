import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  static Future<Uint8List> generateReferralForm(Map<String, dynamic> data) async {
    final content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Referral Form - AfiCare MediLink</title>
      <style>
        @page { margin: 20mm; size: A4; }
        body { font-family: 'Helvetica', 'Arial', sans-serif; color: #333; font-size: 12pt; line-height: 1.5; }
        .header { text-align: center; border-bottom: 3px solid #1D3557; padding-bottom: 10px; margin-bottom: 20px; }
        .header h1 { color: #1D3557; margin: 0; font-size: 20pt; }
        .header h2 { color: #457B9D; margin: 5px 0 0; font-size: 14pt; font-weight: normal; }
        .logo { font-size: 28pt; color: #1D3557; margin-bottom: 5px; }
        .barcode { text-align: center; margin: 15px 0; }
        .barcode svg { width: 200px; height: 60px; }
        .section { margin-bottom: 15px; }
        .section h3 { background: #1D3557; color: white; padding: 6px 12px; margin: 0 0 10px 0; font-size: 12pt; }
        .row { display: flex; margin-bottom: 6px; }
        .label { width: 150px; font-weight: bold; color: #555; }
        .value { flex: 1; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        table th { background: #f0f0f0; text-align: left; padding: 6px; border: 1px solid #ddd; font-size: 10pt; }
        table td { padding: 6px; border: 1px solid #ddd; font-size: 10pt; }
        .footer { text-align: center; margin-top: 30px; padding-top: 10px; border-top: 1px solid #ddd; font-size: 9pt; color: #888; }
        .footer .qr { margin-top: 10px; }
        @media print {
          .no-print { display: none; }
          body { -webkit-print-color-adjust: exact; }
        }
      </style>
    </head>
    <body>
      <div class="header">
        <div class="logo">🏥</div>
        <h1>AfiCare MediLink</h1>
        <h2>Medical Referral Form</h2>
      </div>

      <div class="barcode">
        <svg viewBox="0 0 200 60">
          <rect x="10" y="10" width="3" height="40" fill="#333"/>
          <rect x="15" y="10" width="1" height="40" fill="#333"/>
          <rect x="18" y="10" width="2" height="40" fill="#333"/>
          <rect x="22" y="10" width="4" height="40" fill="#333"/>
          <rect x="28" y="10" width="1" height="40" fill="#333"/>
          <rect x="31" y="10" width="3" height="40" fill="#333"/>
          <rect x="36" y="10" width="2" height="40" fill="#333"/>
          <rect x="40" y="10" width="1" height="40" fill="#333"/>
          <rect x="43" y="10" width="3" height="40" fill="#333"/>
          <rect x="48" y="10" width="4" height="40" fill="#333"/>
          <rect x="54" y="10" width="1" height="40" fill="#333"/>
          <rect x="57" y="10" width="2" height="40" fill="#333"/>
          <rect x="61" y="10" width="3" height="40" fill="#333"/>
          <rect x="66" y="10" width="1" height="40" fill="#333"/>
          <rect x="69" y="10" width="4" height="40" fill="#333"/>
          <rect x="75" y="10" width="2" height="40" fill="#333"/>
          <rect x="79" y="10" width="1" height="40" fill="#333"/>
          <rect x="82" y="10" width="3" height="40" fill="#333"/>
          <rect x="87" y="10" width="2" height="40" fill="#333"/>
          <rect x="91" y="10" width="4" height="40" fill="#333"/>
          <rect x="97" y="10" width="1" height="40" fill="#333"/>
          <rect x="100" y="10" width="3" height="40" fill="#333"/>
          <rect x="105" y="10" width="2" height="40" fill="#333"/>
          <rect x="109" y="10" width="1" height="40" fill="#333"/>
          <rect x="112" y="10" width="4" height="40" fill="#333"/>
          <rect x="118" y="10" width="3" height="40" fill="#333"/>
          <rect x="123" y="10" width="2" height="40" fill="#333"/>
          <rect x="127" y="10" width="1" height="40" fill="#333"/>
          <rect x="130" y="10" width="3" height="40" fill="#333"/>
          <rect x="135" y="10" width="4" height="40" fill="#333"/>
          <rect x="141" y="10" width="1" height="40" fill="#333"/>
          <rect x="144" y="10" width="3" height="40" fill="#333"/>
          <rect x="149" y="10" width="2" height="40" fill="#333"/>
          <rect x="153" y="10" width="1" height="40" fill="#333"/>
          <rect x="156" y="10" width="4" height="40" fill="#333"/>
          <rect x="162" y="10" width="2" height="40" fill="#333"/>
          <rect x="166" y="10" width="3" height="40" fill="#333"/>
          <rect x="171" y="10" width="1" height="40" fill="#333"/>
          <rect x="174" y="10" width="2" height="40" fill="#333"/>
          <rect x="178" y="10" width="3" height="40" fill="#333"/>
          <text x="100" y="55" text-anchor="middle" font-size="8" fill="#333">REF-${data['referral_id'] ?? 'XXXX'}</text>
        </svg>
      </div>

      <div class="section">
        <h3>Patient Information</h3>
        <div class="row"><div class="label">Name:</div><div class="value">${data['patient_name'] ?? ''}</div></div>
        <div class="row"><div class="label">MediLink ID:</div><div class="value">${data['medilink_id'] ?? ''}</div></div>
        <div class="row"><div class="label">Date of Birth:</div><div class="value">${data['dob'] ?? ''}</div></div>
        <div class="row"><div class="label">Gender:</div><div class="value">${data['gender'] ?? ''}</div></div>
      </div>

      <div class="section">
        <h3>Referral Details</h3>
        <div class="row"><div class="label">Referring Provider:</div><div class="value">${data['referring_provider'] ?? ''}</div></div>
        <div class="row"><div class="label">From Facility:</div><div class="value">${data['from_facility'] ?? ''}</div></div>
        <div class="row"><div class="label">To Facility:</div><div class="value">${data['to_facility'] ?? ''}</div></div>
        <div class="row"><div class="label">Specialty:</div><div class="value">${data['specialty'] ?? ''}</div></div>
        <div class="row"><div class="label">Urgency:</div><div class="value">${data['urgency'] ?? ''}</div></div>
      </div>

      <div class="section">
        <h3>Clinical Information</h3>
        <div class="row"><div class="label">Reason:</div><div class="value">${data['reason'] ?? ''}</div></div>
        <div class="row"><div class="label">Clinical Notes:</div><div class="value">${data['clinical_notes'] ?? ''}</div></div>
      </div>

      <div class="footer">
        <p>Generated by AfiCare MediLink on ${_currentDate()}</p>
        <p>This is a computer-generated document. Verify authenticity via QR code.</p>
      </div>
    </body>
    </html>
    ''';
    return _renderHtml(content);
  }

  static Future<Uint8List> generatePrescriptionReceipt(Map<String, dynamic> data) async {
    final content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Prescription Receipt - AfiCare MediLink</title>
      <style>
        @page { margin: 15mm; size: A5; }
        body { font-family: 'Courier New', monospace; color: #333; font-size: 11pt; }
        .header { text-align: center; border-bottom: 2px dashed #333; padding-bottom: 8px; margin-bottom: 15px; }
        .header h1 { font-size: 16pt; margin: 0; }
        .rx-symbol { font-size: 40pt; text-align: center; margin: 5px 0; color: #1D3557; }
        table { width: 100%; border-collapse: collapse; }
        table td { padding: 4px 2px; }
        .label { font-weight: bold; width: 120px; }
        .medication { border: 1px solid #333; padding: 8px; margin: 10px 0; }
        .medication h3 { margin: 0 0 5px 0; font-size: 13pt; }
        .footer { text-align: center; margin-top: 20px; font-size: 8pt; color: #888; border-top: 1px dashed #333; padding-top: 8px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>AfiCare MediLink</h1>
        <p>Prescription Receipt</p>
      </div>
      <div class="rx-symbol">℞</div>
      <table>
        <tr><td class="label">Patient:</td><td>${data['patient_name'] ?? ''}</td></tr>
        <tr><td class="label">MediLink ID:</td><td>${data['medilink_id'] ?? ''}</td></tr>
        <tr><td class="label">Prescribed by:</td><td>${data['provider_name'] ?? ''}</td></tr>
        <tr><td class="label">Date:</td><td>${data['date'] ?? ''}</td></tr>
      </table>
      <div class="medication">
        <h3>${data['medication_name'] ?? ''}</h3>
        <table>
          <tr><td class="label">Dosage:</td><td>${data['dosage'] ?? ''}</td></tr>
          <tr><td class="label">Frequency:</td><td>${data['frequency'] ?? ''}</td></tr>
          <tr><td class="label">Duration:</td><td>${data['duration'] ?? ''}</td></tr>
          <tr><td class="label">Instructions:</td><td>${data['instructions'] ?? ''}</td></tr>
        </table>
      </div>
      <div class="footer">
        QR: ${data['prescription_id'] ?? ''} | ${_currentDate()}
      </div>
    </body>
    </html>
    ''';
    return _renderHtml(content);
  }

  static Future<Uint8List> generateLabResult(Map<String, dynamic> data) async {
    final results = data['results'] as List<Map<String, dynamic>>? ?? [];
    final resultRows = results.map((r) =>
      '<tr><td>${r['test'] ?? ''}</td><td>${r['value'] ?? ''}</td><td>${r['unit'] ?? ''}</td><td>${r['reference'] ?? ''}</td><td>${r['flag'] ?? ''}</td></tr>'
    ).join('\n');

    final content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Lab Results - AfiCare MediLink</title>
      <style>
        @page { margin: 20mm; size: A4; }
        body { font-family: 'Helvetica', 'Arial', sans-serif; color: #333; font-size: 11pt; }
        .header { text-align: center; border-bottom: 2px solid #1D3557; padding-bottom: 10px; }
        .header h1 { color: #1D3557; margin: 0; }
        .patient-info { margin: 15px 0; padding: 10px; background: #f9f9f9; }
        table { width: 100%; border-collapse: collapse; }
        table th { background: #1D3557; color: white; padding: 8px; text-align: left; font-size: 10pt; }
        table td { padding: 6px 8px; border-bottom: 1px solid #ddd; font-size: 10pt; }
        .flag-abnormal { color: #E53935; font-weight: bold; }
        .flag-normal { color: #43A047; }
        .footer { margin-top: 20px; text-align: center; font-size: 9pt; color: #888; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>AfiCare MediLink — Laboratory Results</h1>
        <p>${data['facility_name'] ?? ''}</p>
      </div>
      <div class="patient-info">
        <strong>Patient:</strong> ${data['patient_name'] ?? ''} (${data['medilink_id'] ?? ''})<br>
        <strong>Ordered by:</strong> ${data['provider_name'] ?? ''} | <strong>Date:</strong> ${data['date'] ?? ''}
      </div>
      <table>
        <tr><th>Test</th><th>Result</th><th>Unit</th><th>Reference Range</th><th>Flag</th></tr>
        $resultRows
      </table>
      <div class="footer">
        Generated by AfiCare MediLink | ${_currentDate()}
      </div>
    </body>
    </html>
    ''';
    return _renderHtml(content);
  }

  static Future<Uint8List> generateRadiologyResult(Map<String, dynamic> data) async {
    final content = '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Radiology Report - AfiCare MediLink</title>
      <style>
        @page { margin: 20mm; size: A4; }
        body { font-family: 'Helvetica', 'Arial', sans-serif; color: #333; font-size: 11pt; }
        .header { text-align: center; border-bottom: 3px solid #1D3557; padding-bottom: 10px; }
        .header h1 { color: #1D3557; margin: 0; font-size: 18pt; }
        .patient-info { margin: 15px 0; }
        .section { margin: 15px 0; }
        .section h3 { border-left: 4px solid #1D3557; padding-left: 10px; margin: 0 0 8px 0; }
        .findings-box { background: #f9f9f9; padding: 12px; border-radius: 4px; line-height: 1.6; }
        .impression-box { background: #FFF8E1; padding: 12px; border-left: 4px solid #FFA000; border-radius: 4px; }
        .footer { margin-top: 30px; text-align: center; font-size: 9pt; color: #888; border-top: 1px solid #ddd; padding-top: 10px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>AfiCare MediLink — Radiology Report</h1>
        <p>${data['study_type'] ?? ''} — ${data['body_part'] ?? ''}</p>
      </div>
      <div class="patient-info">
        <strong>Patient:</strong> ${data['patient_name'] ?? ''} (${data['medilink_id'] ?? ''})<br>
        <strong>Radiologist:</strong> ${data['radiologist_name'] ?? ''} | <strong>Date:</strong> ${data['date'] ?? ''}
      </div>
      <div class="section">
        <h3>Findings</h3>
        <div class="findings-box">${data['findings'] ?? ''}</div>
      </div>
      <div class="section">
        <h3>Impression</h3>
        <div class="impression-box">${data['impression'] ?? ''}</div>
      </div>
      <div class="section">
        <h3>Recommendations</h3>
        <p>${data['recommendations'] ?? ''}</p>
      </div>
      <div class="footer">
        Generated by AfiCare MediLink | ${_currentDate()}
      </div>
    </body>
    </html>
    ''';
    return _renderHtml(content);
  }

  static String _currentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<Uint8List> _renderHtml(String html) async {
    final bytes = Uint8List.fromList(html.codeUnits);
    return bytes;
  }

  static Future<String> saveToFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }
}