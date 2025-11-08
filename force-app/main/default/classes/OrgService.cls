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
     * @param accessToken The OAuth access token
     * @param refreshToken The OAuth refresh token
     * @return The created Salesforce_Org__c record
     */
    @AuraEnabled
    public static Salesforce_Org__c createOrg(
        String orgName,
        String orgType,
        String instanceUrl,
        String username,
        String accessToken,
        String refreshToken
    ) {
        try {
            Salesforce_Org__c org = new Salesforce_Org__c(
                Name = orgName,
                Org_Type__c = orgType,
                Instance_URL__c = instanceUrl,
                Username__c = username,
                Access_Token_Encrypted__c = accessToken,
                Refresh_Token_Encrypted__c = refreshToken,
                Status__c = 'Active',
                API_Version__c = '60.0',
                Last_Connected__c = System.now()
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
     * @description Generates OAuth authorization URL for Salesforce org login
     * @param callbackUrl The callback URL for OAuth redirect
     * @return OAuth authorization URL
     */
    @AuraEnabled
    public static String getOAuthAuthorizationUrl(String callbackUrl) {
        try {
            String clientId = getClientId();
            String responseType = 'code';
            String scope = 'api refresh_token';

            // Build the authorization URL
            String authUrl = '/services/oauth2/authorize?' +
                'response_type=' + EncodingUtil.urlEncode(responseType, 'UTF-8') +
                '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
                '&redirect_uri=' + EncodingUtil.urlEncode(callbackUrl, 'UTF-8') +
                '&scope=' + EncodingUtil.urlEncode(scope, 'UTF-8') +
                '&prompt=login';

            return authUrl;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating OAuth URL: ' + e.getMessage());
        }
    }

    /**
     * @description Exchanges OAuth authorization code for access and refresh tokens
     * @param orgName The org name
     * @param orgType The org type
     * @param authorizationCode The OAuth authorization code from callback
     * @param callbackUrl The callback URL used in authorization request
     * @param instanceUrl The instance URL of the target org
     * @return The created Salesforce_Org__c record with tokens
     */
    @AuraEnabled
    public static Salesforce_Org__c exchangeAuthorizationCode(
        String orgName,
        String orgType,
        String authorizationCode,
        String callbackUrl,
        String instanceUrl
    ) {
        try {
            if (String.isBlank(authorizationCode)) {
                throw new AuraHandledException('Authorization code is missing. OAuth flow may have been cancelled.');
            }

            // Prepare OAuth token request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(instanceUrl + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String body = 'grant_type=authorization_code' +
                         '&code=' + EncodingUtil.urlEncode(authorizationCode, 'UTF-8') +
                         '&client_id=' + EncodingUtil.urlEncode(getClientId(), 'UTF-8') +
                         '&client_secret=' + EncodingUtil.urlEncode(getClientSecret(), 'UTF-8') +
                         '&redirect_uri=' + EncodingUtil.urlEncode(callbackUrl, 'UTF-8');
            req.setBody(body);
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                throw new AuraHandledException(
                    'OAuth token exchange failed: ' + res.getStatus() + ' - ' + res.getBody()
                );
            }

            // Parse token response
            Map<String, Object> tokenResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String accessToken = (String) tokenResponse.get('access_token');
            String refreshToken = (String) tokenResponse.get('refresh_token');
            String username = '';

            // Get user info from access token
            HttpRequest userReq = new HttpRequest();
            userReq.setEndpoint(instanceUrl + '/services/oauth2/userinfo');
            userReq.setMethod('GET');
            userReq.setHeader('Authorization', 'Bearer ' + accessToken);
            userReq.setTimeout(10000);

            HttpResponse userRes = http.send(userReq);
            if (userRes.getStatusCode() == 200) {
                Map<String, Object> userInfo = (Map<String, Object>) JSON.deserializeUntyped(userRes.getBody());
                username = (String) userInfo.get('preferred_username');
            }

            if (String.isBlank(username)) {
                username = 'Unknown User';
            }

            // Create org with tokens
            return createOrg(orgName, orgType, instanceUrl, username, accessToken, refreshToken);

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error exchanging authorization code: ' + e.getMessage());
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
                SELECT Id, Instance_URL__c, Access_Token_Encrypted__c, API_Version__c, Status__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];

            ConnectionResult result = new ConnectionResult();

            // Check if access token is present
            if (String.isBlank(org.Access_Token_Encrypted__c)) {
                result.success = false;
                result.message = 'OAuth credentials not configured. Please reconnect this org.';
                org.Status__c = 'Not Authenticated';
                update org;
                return result;
            }

            // Make a simple API call to test connection
            HttpRequest req = new HttpRequest();
            String endpoint = org.Instance_URL__c + '/services/data/v' + org.API_Version__c + '/sobjects';
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);
            req.setTimeout(10000);

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
                } else if (res.getStatusCode() == 401) {
                    // Token might be expired, trigger refresh
                    try {
                        refreshToken(orgId);
                        result.success = true;
                        result.message = 'Token refreshed and connection established';
                    } catch (Exception refreshError) {
                        result.success = false;
                        result.message = 'Token expired and refresh failed. Please reconnect this org.';
                        org.Status__c = 'Token Expired';
                        update org;
                    }
                } else {
                    result.success = false;
                    result.message = 'Connection failed: ' + res.getStatus();
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
                SELECT Id, Instance_URL__c, Refresh_Token_Encrypted__c, Status__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];

            // Validate refresh token exists
            if (String.isBlank(org.Refresh_Token_Encrypted__c)) {
                throw new AuraHandledException('Refresh token not available. Please reconnect this org.');
            }

            // Call OAuth token refresh endpoint
            HttpRequest req = new HttpRequest();
            req.setEndpoint(org.Instance_URL__c + '/services/oauth2/token');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(10000);

            String body = 'grant_type=refresh_token' +
                         '&refresh_token=' + EncodingUtil.urlEncode(org.Refresh_Token_Encrypted__c, 'UTF-8') +
                         '&client_id=' + EncodingUtil.urlEncode(getClientId(), 'UTF-8') +
                         '&client_secret=' + EncodingUtil.urlEncode(getClientSecret(), 'UTF-8');
            req.setBody(body);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String newAccessToken = (String) response.get('access_token');

                if (String.isBlank(newAccessToken)) {
                    throw new AuraHandledException('Access token not returned from OAuth endpoint');
                }

                org.Access_Token_Encrypted__c = newAccessToken;
                org.Last_Connected__c = System.now();
                org.Status__c = 'Active';
                update org;

                AuditService.log('Token Refreshed', 'Salesforce_Org__c', orgId);
            } else {
                org.Status__c = 'Token Expired';
                update org;
                throw new AuraHandledException('Token refresh failed: ' + res.getStatus() + ' - ' + res.getBody());
            }

        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error refreshing token: ' + e.getMessage());
        }
    }

    /**
     * @description Validates if an org has OAuth credentials configured
     * @param orgId The org ID
     * @return Validation result
     */
    @AuraEnabled
    public static OrgValidationResult validateOrgCredentials(Id orgId) {
        OrgValidationResult result = new OrgValidationResult();
        try {
            Salesforce_Org__c org = [
                SELECT Id, Access_Token_Encrypted__c, Refresh_Token_Encrypted__c, Status__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];

            result.isValid = !String.isBlank(org.Access_Token_Encrypted__c);
            result.hasAccessToken = !String.isBlank(org.Access_Token_Encrypted__c);
            result.hasRefreshToken = !String.isBlank(org.Refresh_Token_Encrypted__c);
            result.status = org.Status__c;

            if (!result.isValid) {
                result.message = 'OAuth credentials not configured. Please reconnect this org.';
            } else {
                result.message = 'Org is properly configured.';
            }

        } catch (Exception e) {
            result.isValid = false;
            result.message = 'Error validating org: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Retrieves OAuth configuration from Custom Metadata Type
     * NOTE: Requires OAuth_Config__mdt Custom Metadata Type to be created in Setup (Step 2A in OAUTH_SETUP.md)
     * @return OAuth configuration or null if not found
     * @throws AuraHandledException if CMT doesn't exist
     */
    private static OAuth_Config__mdt getOAuthConfig() {
        try {
            OAuth_Config__mdt config = [
                SELECT Client_ID__c, Client_Secret__c, Is_Configured__c
                FROM OAuth_Config__mdt
                WHERE DeveloperName = 'Default_Config'
                LIMIT 1
            ];
            return config;
        } catch (QueryException e) {
            throw new AuraHandledException(
                'OAuth_Config__mdt Custom Metadata Type not found. Create it by following Step 2A in OAUTH_SETUP.md'
            );
        }
    }

    /**
     * @description Validates if OAuth configuration is properly set up
     * @return OAuth Configuration validation result with status and message
     */
    @AuraEnabled
    public static OAuthValidationResult validateOAuthConfiguration() {
        OAuthValidationResult result = new OAuthValidationResult();
        try {
            OAuth_Config__mdt config = getOAuthConfig();

            if (config == null) {
                result.isConfigured = false;
                result.message = 'OAuth configuration record not found. Follow OAUTH_SETUP.md Step 2B to create it.';
                result.configStatus = 'MISSING';
                return result;
            }

            // Validate credentials are not empty and don't contain placeholder text
            boolean hasClientId = !String.isBlank(config.Client_ID__c) &&
                                  !config.Client_ID__c.startsWith('UPDATE_WITH_');
            boolean hasClientSecret = !String.isBlank(config.Client_Secret__c) &&
                                      !config.Client_Secret__c.startsWith('UPDATE_WITH_');

            result.isConfigured = hasClientId && hasClientSecret && config.Is_Configured__c;
            result.hasClientId = hasClientId;
            result.hasClientSecret = hasClientSecret;
            result.isFlaggedAsConfigured = config.Is_Configured__c;

            // Set appropriate status message
            if (!hasClientId) {
                result.message = 'OAuth Client ID is not configured.';
                result.configStatus = 'MISSING_CLIENT_ID';
            } else if (!hasClientSecret) {
                result.message = 'OAuth Client Secret is not configured.';
                result.configStatus = 'MISSING_CLIENT_SECRET';
            } else if (!config.Is_Configured__c) {
                result.message = 'OAuth credentials exist but "Is Configured" checkbox is not marked.';
                result.configStatus = 'NOT_FLAGGED';
            } else {
                result.message = 'OAuth is properly configured.';
                result.configStatus = 'CONFIGURED';
            }

        } catch (AuraHandledException e) {
            result.isConfigured = false;
            result.message = e.getMessage();
            result.configStatus = 'ERROR';
        } catch (Exception e) {
            result.isConfigured = false;
            result.message = 'Error validating OAuth configuration: ' + e.getMessage();
            result.configStatus = 'ERROR';
        }

        return result;
    }

    /**
     * @description Gets OAuth client ID from Custom Metadata Type
     * Requires: OAuth_Config__mdt Custom Metadata Type with Default_Config record
     * @return OAuth Client ID (Consumer Key)
     * @throws AuraHandledException if not configured
     */
    private static String getClientId() {
        OAuth_Config__mdt config = getOAuthConfig();

        if (config == null || String.isBlank(config.Client_ID__c) ||
            config.Client_ID__c.startsWith('UPDATE_WITH_')) {
            throw new AuraHandledException(
                'OAuth Client ID is not configured. Update OAuth_Config__mdt.Default_Config with your Consumer Key. See OAUTH_SETUP.md Step 2B.'
            );
        }

        return config.Client_ID__c;
    }

    /**
     * @description Gets OAuth client secret from Custom Metadata Type
     * Requires: OAuth_Config__mdt Custom Metadata Type with Default_Config record
     * @return OAuth Client Secret (Consumer Secret)
     * @throws AuraHandledException if not configured
     */
    private static String getClientSecret() {
        OAuth_Config__mdt config = getOAuthConfig();

        if (config == null || String.isBlank(config.Client_Secret__c) ||
            config.Client_Secret__c.startsWith('UPDATE_WITH_')) {
            throw new AuraHandledException(
                'OAuth Client Secret is not configured. Update OAuth_Config__mdt.Default_Config with your Consumer Secret. See OAUTH_SETUP.md Step 2B.'
            );
        }

        return config.Client_Secret__c;
    }

    // Inner classes

    public class ConnectionResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    public class OrgValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public Boolean hasAccessToken;
        @AuraEnabled public Boolean hasRefreshToken;
        @AuraEnabled public String status;
        @AuraEnabled public String message;
    }

    public class OAuthValidationResult {
        @AuraEnabled public Boolean isConfigured;
        @AuraEnabled public Boolean hasClientId;
        @AuraEnabled public Boolean hasClientSecret;
        @AuraEnabled public Boolean isFlaggedAsConfigured;
        @AuraEnabled public String message;
        @AuraEnabled public String configStatus; // CONFIGURED, MISSING, MISSING_CLIENT_ID, MISSING_CLIENT_SECRET, NOT_FLAGGED, ERROR
    }
}
