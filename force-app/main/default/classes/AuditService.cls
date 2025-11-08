/**
 * @description Service class for audit logging
 */
public with sharing class AuditService {

    /**
     * @description Logs an audit entry
     * @param action The action performed
     * @param objectType The type of object affected
     * @param objectId The ID of the object affected
     */
    public static void log(String action, String objectType, Id objectId) {
        log(action, objectType, objectId, null);
    }

    /**
     * @description Logs an audit entry with additional details
     * @param action The action performed
     * @param objectType The type of object affected
     * @param objectId The ID of the object affected
     * @param details Additional details as a Map
     */
    public static void log(String action, String objectType, Id objectId, Map<String, Object> details) {
        try {
            Audit_Log__c auditLog = new Audit_Log__c(
                Action__c = action,
                Object_Type__c = objectType,
                Object_ID__c = String.valueOf(objectId),
                User_ID__c = UserInfo.getUserId(),
                Username__c = UserInfo.getUserName(),
                Timestamp__c = System.now(),
                Details__c = details != null ? JSON.serialize(details) : null
            );

            insert auditLog;
        } catch (Exception e) {
            // Log errors but don't fail the transaction
            System.debug('Error creating audit log: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves audit logs for a specific object
     * @param objectType The object type
     * @param objectId The object ID
     * @return List of audit logs
     */
    @AuraEnabled(cacheable=true)
    public static List<Audit_Log__c> getAuditLogs(String objectType, String objectId) {
        try {
            return [
                SELECT Id, Name, Action__c, Object_Type__c, Object_ID__c,
                       User_ID__c, Username__c, Timestamp__c, Details__c, IP_Address__c
                FROM Audit_Log__c
                WHERE Object_Type__c = :objectType AND Object_ID__c = :objectId
                ORDER BY Timestamp__c DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving audit logs: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all recent audit logs
     * @return List of audit logs
     */
    @AuraEnabled(cacheable=true)
    public static List<Audit_Log__c> getRecentAuditLogs() {
        try {
            return [
                SELECT Id, Name, Action__c, Object_Type__c, Object_ID__c,
                       Username__c, Timestamp__c
                FROM Audit_Log__c
                ORDER BY Timestamp__c DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving audit logs: ' + e.getMessage());
        }
    }
}
