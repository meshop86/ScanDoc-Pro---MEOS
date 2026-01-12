/// Centralized audit event types for Phase 5 integrity
class AuditEventType {
  static const adminUnlock = 'ADMIN_UNLOCK';
  static const labelSetTap = 'LABEL_SET_TAP';
  static const labelSetDoc = 'LABEL_SET_DOC';
  static const deleteBo = 'DELETE_BO';
  static const renameBo = 'RENAME_BO';
  static const finalizeTap = 'FINALIZE_TAP';
  static const exportZip = 'EXPORT_ZIP';
  static const exportZipAdmin = 'EXPORT_ZIP_ADMIN_OVERRIDE';
  static const exportPdf = 'EXPORT_PDF';
  static const exportPdfAdmin = 'EXPORT_PDF_ADMIN_OVERRIDE';
  static const zipTap = 'ZIP_TAP';
  static const scan = 'SCAN';
  static const quotaCheck = 'QUOTA_CHECK';
  static const quotaBlocked = 'QUOTA_BLOCKED';
  static const quotaReset = 'QUOTA_RESET';
  static const systemRecover = 'SYSTEM_RECOVER';
}
