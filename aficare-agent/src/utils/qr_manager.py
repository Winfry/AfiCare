"""
QR Code Manager for AfiCare MediLink
Handles QR code generation and validation for patient record access
"""

import json
import base64
import secrets
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, Tuple
import logging
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
import qrcode
from io import BytesIO

logger = logging.getLogger(__name__)


class QRCodeManager:
    """Manages QR code generation and validation for patient access"""
    
    def __init__(self, database_manager=None):
        self.db = database_manager
        self.encryption_key = self._load_or_generate_key()
        self.cipher_suite = Fernet(self.encryption_key)
    
    def _load_or_generate_key(self) -> bytes:
        """Load or generate encryption key for QR codes"""
        try:
            # In production, this should be stored securely (environment variable, key management service)
            # For demo purposes, we'll use a derived key
            password = b"aficare_medilink_qr_encryption_key_2024"
            salt = b"medilink_salt_for_qr_codes"
            
            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=100000,
            )
            key = base64.urlsafe_b64encode(kdf.derive(password))
            return key
            
        except Exception as e:
            logger.error(f"Failed to generate encryption key: {str(e)}")
            # Fallback to a simple key (not recommended for production)
            return Fernet.generate_key()
    
    def generate_patient_qr(self, medilink_id: str, duration_hours: int = 24,
                           permissions: Dict[str, bool] = None, 
                           access_code: str = None) -> Tuple[bool, Optional[bytes], Optional[str]]:
        """Generate QR code for patient record access"""
        
        try:
            # If no access code provided, generate one
            if not access_code and self.db:
                success, access_code = self.db.generate_access_code(
                    medilink_id, duration_hours, permissions
                )
                if not success:
                    return False, None, None
            
            # Create QR payload
            expires_at = datetime.now() + timedelta(hours=duration_hours)
            qr_payload = {
                "medilink_id": medilink_id,
                "access_code": access_code,
                "expires_at": expires_at.isoformat(),
                "permissions": permissions or {},
                "generated_at": datetime.now().isoformat(),
                "version": "1.0"
            }
            
            # Encrypt the payload
            encrypted_data = self._encrypt_qr_payload(qr_payload)
            if not encrypted_data:
                return False, None, None
            
            # Generate QR code image
            qr_image = self.create_qr_image(encrypted_data)
            
            logger.info(f"QR code generated for patient {medilink_id}")
            return True, qr_image, access_code
            
        except Exception as e:
            logger.error(f"Failed to generate patient QR code: {str(e)}")
            return False, None, None
    
    def validate_qr_data(self, qr_data: str, accessed_by: str) -> Tuple[bool, Optional[str], Optional[Dict[str, bool]]]:
        """Validate QR code data and return patient info if valid"""
        
        try:
            # Decrypt QR payload
            payload = self._decrypt_qr_payload(qr_data)
            if not payload:
                return False, None, None
            
            # Check expiration
            expires_at = datetime.fromisoformat(payload.get("expires_at", ""))
            if datetime.now() > expires_at:
                logger.warning(f"QR code expired for {payload.get('medilink_id')}")
                return False, None, None
            
            # Verify access code if database is available
            medilink_id = payload.get("medilink_id")
            access_code = payload.get("access_code")
            permissions = payload.get("permissions", {})
            
            if self.db and access_code:
                # Verify the access code is still valid
                success, verified_medilink_id, verified_permissions = self.db.verify_access_code(
                    access_code, accessed_by, mark_as_used=False
                )
                
                if not success or verified_medilink_id != medilink_id:
                    logger.warning(f"QR code access code verification failed for {medilink_id}")
                    return False, None, None
                
                # Use verified permissions
                permissions = verified_permissions or permissions
                
                # Log QR code access
                self.db.log_access_enhanced(
                    patient_medilink_id=medilink_id,
                    accessed_by=accessed_by,
                    access_type="qr_code_access",
                    access_method="qr_code",
                    success=True
                )
            
            logger.info(f"QR code validated for patient {medilink_id} by {accessed_by}")
            return True, medilink_id, permissions
            
        except Exception as e:
            logger.error(f"Failed to validate QR code: {str(e)}")
            return False, None, None
    
    def create_qr_image(self, qr_data: str, size: int = 200) -> bytes:
        """Create QR code image from data"""
        
        try:
            # Create QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(qr_data)
            qr.make(fit=True)
            
            # Create image
            img = qr.make_image(fill_color="black", back_color="white")
            
            # Resize if needed
            if size != 200:
                img = img.resize((size, size))
            
            # Convert to bytes
            img_buffer = BytesIO()
            img.save(img_buffer, format='PNG')
            img_bytes = img_buffer.getvalue()
            
            return img_bytes
            
        except Exception as e:
            logger.error(f"Failed to create QR code image: {str(e)}")
            return b""
    
    def _encrypt_qr_payload(self, payload: Dict[str, Any]) -> Optional[str]:
        """Encrypt QR code payload"""
        
        try:
            # Convert payload to JSON string
            payload_json = json.dumps(payload, separators=(',', ':'))
            payload_bytes = payload_json.encode('utf-8')
            
            # Encrypt the payload
            encrypted_data = self.cipher_suite.encrypt(payload_bytes)
            
            # Encode to base64 for QR code
            encoded_data = base64.urlsafe_b64encode(encrypted_data).decode('utf-8')
            
            return encoded_data
            
        except Exception as e:
            logger.error(f"Failed to encrypt QR payload: {str(e)}")
            return None
    
    def _decrypt_qr_payload(self, encrypted_data: str) -> Optional[Dict[str, Any]]:
        """Decrypt QR code payload"""
        
        try:
            # Decode from base64
            encrypted_bytes = base64.urlsafe_b64decode(encrypted_data.encode('utf-8'))
            
            # Decrypt the payload
            decrypted_bytes = self.cipher_suite.decrypt(encrypted_bytes)
            
            # Convert back to dictionary
            payload_json = decrypted_bytes.decode('utf-8')
            payload = json.loads(payload_json)
            
            return payload
            
        except Exception as e:
            logger.error(f"Failed to decrypt QR payload: {str(e)}")
            return None
    
    def generate_verification_qr(self, data: Dict[str, Any]) -> bytes:
        """Generate QR code for data verification (exports, reports)"""
        
        try:
            # Create verification payload
            verification_payload = {
                "type": "verification",
                "data_hash": self._calculate_data_hash(data),
                "generated_at": datetime.now().isoformat(),
                "system": "AfiCare MediLink",
                "version": "1.0"
            }
            
            # Create QR code with verification data
            verification_json = json.dumps(verification_payload, separators=(',', ':'))
            qr_image = self.create_qr_image(verification_json, size=150)
            
            return qr_image
            
        except Exception as e:
            logger.error(f"Failed to generate verification QR code: {str(e)}")
            return b""
    
    def verify_data_qr(self, qr_data: str, original_data: Dict[str, Any]) -> bool:
        """Verify data integrity using QR code"""
        
        try:
            # Parse QR data
            verification_payload = json.loads(qr_data)
            
            if verification_payload.get("type") != "verification":
                return False
            
            # Calculate hash of original data
            original_hash = self._calculate_data_hash(original_data)
            qr_hash = verification_payload.get("data_hash")
            
            # Compare hashes
            return original_hash == qr_hash
            
        except Exception as e:
            logger.error(f"Failed to verify data QR code: {str(e)}")
            return False
    
    def _calculate_data_hash(self, data: Dict[str, Any]) -> str:
        """Calculate hash of data for verification"""
        
        try:
            # Convert data to consistent JSON string
            data_json = json.dumps(data, sort_keys=True, separators=(',', ':'))
            data_bytes = data_json.encode('utf-8')
            
            # Calculate SHA-256 hash
            digest = hashes.Hash(hashes.SHA256())
            digest.update(data_bytes)
            hash_bytes = digest.finalize()
            
            # Return as hex string
            return hash_bytes.hex()
            
        except Exception as e:
            logger.error(f"Failed to calculate data hash: {str(e)}")
            return ""
    
    def create_patient_access_qr_display(self, medilink_id: str, access_code: str, 
                                       expires_at: datetime, permissions: Dict[str, bool]) -> Dict[str, Any]:
        """Create display information for patient access QR code"""
        
        try:
            # Generate QR code
            success, qr_image, _ = self.generate_patient_qr(
                medilink_id, 
                duration_hours=int((expires_at - datetime.now()).total_seconds() / 3600),
                permissions=permissions,
                access_code=access_code
            )
            
            if not success:
                return {"success": False, "error": "Failed to generate QR code"}
            
            # Create display info
            display_info = {
                "success": True,
                "qr_image": qr_image,
                "access_code": access_code,
                "expires_at": expires_at.strftime("%Y-%m-%d %H:%M:%S"),
                "permissions": permissions,
                "instructions": [
                    "Show this QR code to your healthcare provider",
                    "They can scan it to access your medical records",
                    f"This code expires on {expires_at.strftime('%B %d, %Y at %I:%M %p')}",
                    "You can revoke access at any time from your dashboard"
                ]
            }
            
            return display_info
            
        except Exception as e:
            logger.error(f"Failed to create QR display info: {str(e)}")
            return {"success": False, "error": str(e)}


# Global QR manager instance
qr_manager = None

def get_qr_manager(database_manager=None):
    """Get global QR manager instance"""
    global qr_manager
    if qr_manager is None:
        qr_manager = QRCodeManager(database_manager)
    return qr_manager