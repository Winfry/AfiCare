"""
Export Manager for AfiCare MediLink
Handles patient data export in multiple formats (PDF, JSON, CSV)
"""

import json
import csv
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
import logging
from io import BytesIO, StringIO
from pathlib import Path

# PDF generation
try:
    from reportlab.lib.pagesizes import letter, A4
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.lib.units import inch
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT
    PDF_AVAILABLE = True
except ImportError:
    PDF_AVAILABLE = False
    logger = logging.getLogger(__name__)
    logger.warning("ReportLab not available - PDF export will be disabled")

logger = logging.getLogger(__name__)


class ExportManager:
    """Manages patient data export in various formats"""
    
    def __init__(self, database_manager=None, qr_manager=None):
        self.db = database_manager
        self.qr_manager = qr_manager
    
    def export_patient_data(self, medilink_id: str, export_format: str = 'pdf',
                           date_range: Tuple[Optional[str], Optional[str]] = (None, None),
                           data_types: List[str] = None, exported_by: str = None,
                           export_purpose: str = "patient_request") -> Tuple[bool, Optional[bytes], str]:
        """Export patient data in specified format"""
        
        try:
            if not self.db:
                return False, None, "Database not available"
            
            # Get patient data
            patient_data = self._gather_patient_data(medilink_id, date_range, data_types)
            if not patient_data:
                return False, None, "No patient data found"
            
            # Export based on format
            if export_format.lower() == 'pdf':
                success, export_data, message = self._export_to_pdf(patient_data)
            elif export_format.lower() == 'json':
                success, export_data, message = self._export_to_json(patient_data)
            elif export_format.lower() == 'csv':
                success, export_data, message = self._export_to_csv(patient_data)
            else:
                return False, None, f"Unsupported export format: {export_format}"
            
            if success and export_data:
                # Log export activity
                file_size = len(export_data) if isinstance(export_data, bytes) else len(export_data.encode('utf-8'))
                self.db.log_export_activity(
                    medilink_id=medilink_id,
                    exported_by=exported_by or "patient",
                    export_format=export_format,
                    data_types=data_types or ["all"],
                    file_size=file_size,
                    export_purpose=export_purpose,
                    success=True
                )
            
            return success, export_data, message
            
        except Exception as e:
            logger.error(f"Failed to export patient data: {str(e)}")
            return False, None, f"Export failed: {str(e)}"
    
    def _gather_patient_data(self, medilink_id: str, date_range: Tuple[Optional[str], Optional[str]],
                           data_types: List[str] = None) -> Optional[Dict[str, Any]]:
        """Gather patient data for export"""
        
        try:
            # Get basic patient info
            patient_info = self.db.get_user_by_medilink_id(medilink_id)
            if not patient_info:
                return None
            
            # Get patient profile
            patient_profile = self.db.get_patient_profile(medilink_id)
            
            # Get consultations
            consultations = self.db.get_patient_consultations(medilink_id)
            
            # Filter consultations by date range if specified
            if date_range[0] or date_range[1]:
                filtered_consultations = []
                for consultation in consultations:
                    consult_date = datetime.fromisoformat(consultation['consultation_date'].replace('Z', '+00:00'))
                    
                    if date_range[0]:
                        start_date = datetime.fromisoformat(date_range[0])
                        if consult_date < start_date:
                            continue
                    
                    if date_range[1]:
                        end_date = datetime.fromisoformat(date_range[1])
                        if consult_date > end_date:
                            continue
                    
                    filtered_consultations.append(consultation)
                
                consultations = filtered_consultations
            
            # Get access log (recent)
            access_log = self.db.get_access_log_enhanced(medilink_id, days=30)
            
            # Compile patient data
            patient_data = {
                "patient_info": patient_info,
                "patient_profile": patient_profile or {},
                "consultations": consultations,
                "access_log": access_log,
                "export_metadata": {
                    "exported_at": datetime.now().isoformat(),
                    "date_range": date_range,
                    "data_types": data_types or ["all"],
                    "total_consultations": len(consultations),
                    "system": "AfiCare MediLink"
                }
            }
            
            return patient_data
            
        except Exception as e:
            logger.error(f"Failed to gather patient data: {str(e)}")
            return None
    
    def _export_to_pdf(self, patient_data: Dict[str, Any]) -> Tuple[bool, Optional[bytes], str]:
        """Export patient data to PDF format"""
        
        if not PDF_AVAILABLE:
            return False, None, "PDF export not available - ReportLab library not installed"
        
        try:
            buffer = BytesIO()
            doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=72, leftMargin=72,
                                  topMargin=72, bottomMargin=18)
            
            # Get styles
            styles = getSampleStyleSheet()
            title_style = ParagraphStyle(
                'CustomTitle',
                parent=styles['Heading1'],
                fontSize=18,
                spaceAfter=30,
                alignment=TA_CENTER
            )
            
            story = []
            
            # Title
            story.append(Paragraph("AfiCare MediLink - Medical Records Export", title_style))
            story.append(Spacer(1, 12))
            
            # Patient Information
            patient_info = patient_data["patient_info"]
            story.append(Paragraph("Patient Information", styles['Heading2']))
            
            patient_table_data = [
                ["MediLink ID:", patient_info.get('medilink_id', 'N/A')],
                ["Full Name:", patient_info.get('full_name', 'N/A')],
                ["Age:", str(patient_info.get('age', 'N/A'))],
                ["Gender:", patient_info.get('gender', 'N/A')],
                ["Phone:", patient_info.get('phone', 'N/A')],
                ["Email:", patient_info.get('email', 'N/A')],
            ]
            
            patient_table = Table(patient_table_data, colWidths=[2*inch, 3*inch])
            patient_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
                ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
                ('BACKGROUND', (1, 0), (1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black)
            ]))
            
            story.append(patient_table)
            story.append(Spacer(1, 12))
            
            # Patient Profile
            patient_profile = patient_data.get("patient_profile", {})
            if patient_profile:
                story.append(Paragraph("Medical Profile", styles['Heading2']))
                
                profile_data = []
                if patient_profile.get('allergies'):
                    profile_data.append(["Allergies:", ", ".join(patient_profile['allergies'])])
                if patient_profile.get('chronic_conditions'):
                    profile_data.append(["Chronic Conditions:", ", ".join(patient_profile['chronic_conditions'])])
                if patient_profile.get('blood_type'):
                    profile_data.append(["Blood Type:", patient_profile['blood_type']])
                if patient_profile.get('medical_alerts'):
                    profile_data.append(["Medical Alerts:", ", ".join(patient_profile['medical_alerts'])])
                
                if profile_data:
                    profile_table = Table(profile_data, colWidths=[2*inch, 3*inch])
                    profile_table.setStyle(TableStyle([
                        ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
                        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
                        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                        ('FONTSIZE', (0, 0), (-1, -1), 10),
                        ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
                        ('BACKGROUND', (1, 0), (1, -1), colors.beige),
                        ('GRID', (0, 0), (-1, -1), 1, colors.black)
                    ]))
                    story.append(profile_table)
                    story.append(Spacer(1, 12))
            
            # Consultations
            consultations = patient_data.get("consultations", [])
            if consultations:
                story.append(Paragraph("Medical Consultations", styles['Heading2']))
                
                for i, consultation in enumerate(consultations[:10]):  # Limit to 10 most recent
                    story.append(Paragraph(f"Consultation {i+1}", styles['Heading3']))
                    
                    consult_data = [
                        ["Date:", consultation.get('consultation_date', 'N/A')[:16]],
                        ["Doctor:", consultation.get('doctor_username', 'N/A')],
                        ["Chief Complaint:", consultation.get('chief_complaint', 'N/A')],
                        ["Triage Level:", consultation.get('triage_level', 'N/A')],
                    ]
                    
                    # Add suspected conditions
                    if consultation.get('suspected_conditions'):
                        conditions = consultation['suspected_conditions']
                        if conditions and len(conditions) > 0:
                            top_condition = conditions[0]
                            condition_text = f"{top_condition.get('display_name', 'Unknown')} ({top_condition.get('confidence', 0):.1%})"
                            consult_data.append(["Top Diagnosis:", condition_text])
                    
                    consult_table = Table(consult_data, colWidths=[2*inch, 3*inch])
                    consult_table.setStyle(TableStyle([
                        ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
                        ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
                        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                        ('FONTSIZE', (0, 0), (-1, -1), 9),
                        ('BOTTOMPADDING', (0, 0), (-1, -1), 8),
                        ('BACKGROUND', (1, 0), (1, -1), colors.beige),
                        ('GRID', (0, 0), (-1, -1), 1, colors.black)
                    ]))
                    
                    story.append(consult_table)
                    story.append(Spacer(1, 8))
            
            # Export metadata
            story.append(Spacer(1, 12))
            story.append(Paragraph("Export Information", styles['Heading2']))
            
            export_meta = patient_data["export_metadata"]
            meta_data = [
                ["Export Date:", export_meta.get('exported_at', 'N/A')[:16]],
                ["Total Consultations:", str(export_meta.get('total_consultations', 0))],
                ["System:", export_meta.get('system', 'AfiCare MediLink')],
            ]
            
            meta_table = Table(meta_data, colWidths=[2*inch, 3*inch])
            meta_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (0, -1), colors.lightgrey),
                ('TEXTCOLOR', (0, 0), (-1, -1), colors.black),
                ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
                ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 0), (-1, -1), 10),
                ('BOTTOMPADDING', (0, 0), (-1, -1), 12),
                ('BACKGROUND', (1, 0), (1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black)
            ]))
            
            story.append(meta_table)
            
            # Add verification QR code if QR manager is available
            if self.qr_manager:
                try:
                    qr_image_bytes = self.qr_manager.generate_verification_qr(patient_data)
                    if qr_image_bytes:
                        story.append(Spacer(1, 12))
                        story.append(Paragraph("Verification QR Code", styles['Heading3']))
                        
                        # Create temporary file for QR image
                        qr_buffer = BytesIO(qr_image_bytes)
                        qr_img = Image(qr_buffer, width=1.5*inch, height=1.5*inch)
                        story.append(qr_img)
                        story.append(Paragraph("Scan to verify document authenticity", styles['Normal']))
                except Exception as e:
                    logger.warning(f"Failed to add verification QR code: {str(e)}")
            
            # Build PDF
            doc.build(story)
            pdf_data = buffer.getvalue()
            buffer.close()
            
            return True, pdf_data, "PDF export successful"
            
        except Exception as e:
            logger.error(f"Failed to create PDF export: {str(e)}")
            return False, None, f"PDF export failed: {str(e)}"
    
    def _export_to_json(self, patient_data: Dict[str, Any]) -> Tuple[bool, Optional[str], str]:
        """Export patient data to JSON format"""
        
        try:
            # Clean up data for JSON serialization
            clean_data = self._clean_data_for_json(patient_data)
            
            # Convert to JSON with pretty formatting
            json_data = json.dumps(clean_data, indent=2, ensure_ascii=False, default=str)
            
            return True, json_data, "JSON export successful"
            
        except Exception as e:
            logger.error(f"Failed to create JSON export: {str(e)}")
            return False, None, f"JSON export failed: {str(e)}"
    
    def _export_to_csv(self, patient_data: Dict[str, Any]) -> Tuple[bool, Optional[str], str]:
        """Export patient consultations to CSV format"""
        
        try:
            output = StringIO()
            writer = csv.writer(output)
            
            # Write header
            headers = [
                'Date', 'Doctor', 'Chief Complaint', 'Triage Level', 
                'Top Diagnosis', 'Confidence', 'Symptoms', 'Recommendations'
            ]
            writer.writerow(headers)
            
            # Write consultation data
            consultations = patient_data.get("consultations", [])
            for consultation in consultations:
                # Get top diagnosis
                top_diagnosis = ""
                confidence = ""
                if consultation.get('suspected_conditions'):
                    conditions = consultation['suspected_conditions']
                    if conditions and len(conditions) > 0:
                        top_condition = conditions[0]
                        top_diagnosis = top_condition.get('display_name', '')
                        confidence = f"{top_condition.get('confidence', 0):.1%}"
                
                # Get symptoms
                symptoms = ""
                if consultation.get('symptoms'):
                    symptoms = ", ".join(consultation['symptoms'])
                
                # Get recommendations
                recommendations = ""
                if consultation.get('recommendations'):
                    recommendations = "; ".join(consultation['recommendations'][:3])  # First 3
                
                row = [
                    consultation.get('consultation_date', '')[:16],
                    consultation.get('doctor_username', ''),
                    consultation.get('chief_complaint', ''),
                    consultation.get('triage_level', ''),
                    top_diagnosis,
                    confidence,
                    symptoms,
                    recommendations
                ]
                
                writer.writerow(row)
            
            csv_data = output.getvalue()
            output.close()
            
            return True, csv_data, "CSV export successful"
            
        except Exception as e:
            logger.error(f"Failed to create CSV export: {str(e)}")
            return False, None, f"CSV export failed: {str(e)}"
    
    def _clean_data_for_json(self, data: Any) -> Any:
        """Clean data for JSON serialization"""
        
        if isinstance(data, dict):
            return {key: self._clean_data_for_json(value) for key, value in data.items()}
        elif isinstance(data, list):
            return [self._clean_data_for_json(item) for item in data]
        elif isinstance(data, datetime):
            return data.isoformat()
        elif data is None:
            return None
        else:
            return data
    
    def generate_patient_summary(self, medilink_id: str, provider: str, 
                               purpose: str = "consultation") -> Dict[str, Any]:
        """Generate patient summary report for healthcare providers"""
        
        try:
            if not self.db:
                return {"success": False, "error": "Database not available"}
            
            # Get patient data
            patient_info = self.db.get_user_by_medilink_id(medilink_id)
            if not patient_info:
                return {"success": False, "error": "Patient not found"}
            
            patient_profile = self.db.get_patient_profile(medilink_id)
            consultations = self.db.get_patient_consultations(medilink_id)
            
            # Generate summary based on purpose
            if purpose == "referral":
                summary = self._generate_referral_summary(patient_info, patient_profile, consultations)
            elif purpose == "discharge":
                summary = self._generate_discharge_summary(patient_info, patient_profile, consultations)
            else:  # consultation
                summary = self._generate_consultation_summary(patient_info, patient_profile, consultations)
            
            # Add metadata
            summary.update({
                "generated_by": provider,
                "generated_at": datetime.now().isoformat(),
                "purpose": purpose,
                "patient_medilink_id": medilink_id
            })
            
            return {"success": True, "summary": summary}
            
        except Exception as e:
            logger.error(f"Failed to generate patient summary: {str(e)}")
            return {"success": False, "error": str(e)}
    
    def _generate_consultation_summary(self, patient_info: Dict, patient_profile: Dict, 
                                     consultations: List[Dict]) -> Dict[str, Any]:
        """Generate consultation summary"""
        
        recent_consultations = consultations[:5]  # Last 5 consultations
        
        # Extract key information
        chronic_conditions = patient_profile.get('chronic_conditions', []) if patient_profile else []
        allergies = patient_profile.get('allergies', []) if patient_profile else []
        current_medications = patient_profile.get('current_medications', []) if patient_profile else []
        
        # Recent diagnoses
        recent_diagnoses = []
        for consultation in recent_consultations:
            if consultation.get('suspected_conditions'):
                conditions = consultation['suspected_conditions']
                if conditions:
                    recent_diagnoses.append({
                        "date": consultation['consultation_date'][:10],
                        "diagnosis": conditions[0].get('display_name', 'Unknown'),
                        "confidence": conditions[0].get('confidence', 0)
                    })
        
        return {
            "patient_overview": {
                "name": patient_info.get('full_name'),
                "age": patient_info.get('age'),
                "gender": patient_info.get('gender'),
                "medilink_id": patient_info.get('medilink_id')
            },
            "medical_alerts": {
                "allergies": allergies,
                "chronic_conditions": chronic_conditions,
                "current_medications": current_medications
            },
            "recent_activity": {
                "total_consultations": len(consultations),
                "recent_consultations": len(recent_consultations),
                "last_visit": consultations[0]['consultation_date'][:10] if consultations else None,
                "recent_diagnoses": recent_diagnoses
            }
        }
    
    def _generate_referral_summary(self, patient_info: Dict, patient_profile: Dict, 
                                 consultations: List[Dict]) -> Dict[str, Any]:
        """Generate referral summary"""
        
        base_summary = self._generate_consultation_summary(patient_info, patient_profile, consultations)
        
        # Add referral-specific information
        base_summary["referral_reason"] = "Specialist consultation required"
        base_summary["referring_provider"] = "Primary Care"
        
        return base_summary
    
    def _generate_discharge_summary(self, patient_info: Dict, patient_profile: Dict, 
                                  consultations: List[Dict]) -> Dict[str, Any]:
        """Generate discharge summary"""
        
        base_summary = self._generate_consultation_summary(patient_info, patient_profile, consultations)
        
        # Add discharge-specific information
        if consultations:
            latest_consultation = consultations[0]
            base_summary["discharge_diagnosis"] = latest_consultation.get('suspected_conditions', [])
            base_summary["discharge_recommendations"] = latest_consultation.get('recommendations', [])
        
        return base_summary


# Global export manager instance
export_manager = None

def get_export_manager(database_manager=None, qr_manager=None):
    """Get global export manager instance"""
    global export_manager
    if export_manager is None:
        export_manager = ExportManager(database_manager, qr_manager)
    return export_manager