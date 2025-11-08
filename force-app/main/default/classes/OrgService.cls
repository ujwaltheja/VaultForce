/**
 * @description Service class for managing Salesforce org connections
 */
public with sharing class OrgService {

    /**
     * @description Creates a new Salesforce org connection
     * @param orgName The name of the org
     * @param orgType The type of org (Production, Sandbox, Developer, Scratch)
     * @param instanceUrl The instance URL
     * @param username The username
     * @return The created Salesforce_Org__c record
     */
    @AuraEnabled
    public static Salesforce_Org__c createOrg(
        String orgName,
        String orgType,
        String instanceUrl,
        String username
    ) {
        try {
            Salesforce_Org__c org = new Salesforce_Org__c(
                Name = orgName,
                Org_Type__c = orgType,
                Instance_URL__c = instanceUrl,
                Username__c = username,
                Status__c = 'Active',
                API_Version__c = '60.0'
            );
            insert org;

            // Log audit
            AuditService.log('Org Connected', 'Salesforce_Org__c', org.Id);

            return org;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating org: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all Salesforce org connections
     * @return List of orgs
     */
    @AuraEnabled(cacheable=true)
    public static List<Salesforce_Org__c> getOrgs() {
        try {
            return [
                SELECT Id, Name, Org_Type__c, Instance_URL__c, Username__c,
                       Status__c, Last_Connected__c, CreatedDate
                FROM Salesforce_Org__c
                ORDER BY Name ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving orgs: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves a specific Salesforce org
     * @param orgId The org ID
     * @return Org record
     */
    @AuraEnabled(cacheable=true)
    public static Salesforce_Org__c getOrg(Id orgId) {
        try {
            return [
                SELECT Id, Name, Org_Type__c, Instance_URL__c, Username__c,
                       Org_ID__c, Status__c, Last_Connected__c, API_Version__c,
                       Description__c, CreatedDate, LastModifiedDate
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving org: ' + e.getMessage());
        }
    }

    /**
     * @description Updates a Salesforce org connection
     * @param orgId The org ID
     * @param orgName The org name
     * @param description The org description
     * @return Updated org record
     */
    @AuraEnabled
    public static Salesforce_Org__c updateOrg(Id orgId, String orgName, String description) {
        try {
            Salesforce_Org__c org = [
                SELECT Id, Name, Description__c FROM Salesforce_Org__c WHERE Id = :orgId LIMIT 1
            ];

            org.Name = orgName;
            org.Description__c = description;
            update org;

            return org;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating org: ' + e.getMessage());
        }
    }

    /**
     * @description Deletes a Salesforce org connection
     * @param orgId The org ID
     */
    @AuraEnabled
    public static void deleteOrg(Id orgId) {
        try {
            Salesforce_Org__c org = [
                SELECT Id FROM Salesforce_Org__c WHERE Id = :orgId LIMIT 1
            ];

            delete org;

            AuditService.log('Org Disconnected', 'Salesforce_Org__c', orgId);
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting org: ' + e.getMessage());
        }
    }

    /**
     * @description Tests connection to a Salesforce org
     * @param orgId The org ID
     * @return Connection test result
     */
    @AuraEnabled
    public static ConnectionResult testConnection(Id orgId) {
        try {
            Salesforce_Org__c org = [
                SELECT Id, Instance_URL__c, Access_Token_Encrypted__c, API_Version__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];

            // Make a simple API call to test connection
            HttpRequest req = new HttpRequest();
            String endpoint = org.Instance_URL__c + '/services/data/v' + org.API_Version__c + '/sobjects';
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);

            ConnectionResult result = new ConnectionResult();

            try {
                Http http = new Http();
                HttpResponse res = http.send(req);

                if (res.getStatusCode() == 200) {
                    result.success = true;
                    result.message = 'Connection successful';

                    // Update last connected timestamp
                    org.Last_Connected__c = System.now();
                    org.Status__c = 'Active';
                    update org;
                } else {
                    result.success = false;
                    result.message = 'Connection failed: ' + res.getBody();
                    org.Status__c = 'Error';
                    update org;
                }
            } catch (Exception e) {
                result.success = false;
                result.message = 'Connection error: ' + e.getMessage();
                org.Status__c = 'Error';
                update org;
            }

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error testing connection: ' + e.getMessage());
        }
    }

    /**
     * @description Refreshes OAuth token for a Salesforce org
     * @param orgId The org ID
     */
    @AuraEnabled
    public static void refreshToken(Id orgId) {
        try {
            Salesforce_Org__c org = [
                SELECT Id, Instance_URL__c, Refresh_Token_Encrypted__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];

            // Call OAuth token refresh endpoint
            HttpRequest req = new HttpRequest();
            req.setEndpoint(org.Instance_URL__c + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String body = 'grant_type=refresh_token' +
                         '&refresh_token=' + org.Refresh_Token_Encrypted__c +
                         '&client_id=' + getClientId() +
                         '&client_secret=' + getClientSecret();
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newAccessToken = (String) response.get('access_token');

                org.Access_Token_Encrypted__c = newAccessToken;
                org.Last_Connected__c = System.now();
                org.Status__c = 'Active';
                update org;
            } else {
                org.Status__c = 'Expired';
                update org;
                throw new AuraHandledException('Token refresh failed: ' + res.getBody());
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error refreshing token: ' + e.getMessage());
        }
    }

    /**
     * @description Gets OAuth client ID from custom metadata
     */
    private static String getClientId() {
        // In a real implementation, retrieve from Custom Metadata Type
        return 'YOUR_CLIENT_ID';
    }

    /**
     * @description Gets OAuth client secret from custom metadata
     */
    private static String getClientSecret() {
        // In a real implementation, retrieve from Named Credentials or Custom Metadata
        return 'YOUR_CLIENT_SECRET';
    }

    // Inner classes

    public class ConnectionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
}
