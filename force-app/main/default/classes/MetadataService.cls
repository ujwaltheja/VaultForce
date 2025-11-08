/**
 * @description Service class for interacting with Salesforce Metadata API
 * Handles metadata retrieval, deployment, and management operations
 */
public with sharing class MetadataService {

    /**
     * @description Retrieves metadata from a connected Salesforce org
     * @param orgId The ID of the Salesforce_Org__c record
     * @param metadataTypes List of metadata types to retrieve
     * @return Map of metadata type to metadata components
     */
    public static Map<String, List<MetadataComponent>> retrieveMetadata(
        Id orgId,
        List<String> metadataTypes
    ) {
        Salesforce_Org__c org = [
            SELECT Id, Instance_URL__c, Access_Token_Encrypted__c, API_Version__c
            FROM Salesforce_Org__c
            WHERE Id = :orgId
            LIMIT 1
        ];

        Map<String, List<MetadataComponent>> metadataMap = new Map<String, List<MetadataComponent>>();

        // Call Metadata API for each metadata type
        for (String metadataType : metadataTypes) {
            List<MetadataComponent> components = listMetadataComponents(org, metadataType);
            metadataMap.put(metadataType, components);
        }

        return metadataMap;
    }

    /**
     * @description Lists metadata components of a specific type
     * @param org The Salesforce org record
     * @param metadataType The type of metadata to list
     * @return List of metadata components
     */
    private static List<MetadataComponent> listMetadataComponents(
        Salesforce_Org__c org,
        String metadataType
    ) {
        List<MetadataComponent> components = new List<MetadataComponent>();

        // Construct Metadata API request
        HttpRequest req = new HttpRequest();
        String endpoint = org.Instance_URL__c + '/services/data/v' + org.API_Version__c + '/metadata/listMetadata';
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);
        req.setHeader('Content-Type', 'application/json');

        // Request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'type' => metadataType
        };
        req.setBody(JSON.serialize(requestBody));

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());

                for (Object result : results) {
                    Map<String, Object> resultMap = (Map<String, Object>) result;
                    MetadataComponent component = new MetadataComponent();
                    component.fullName = (String) resultMap.get('fullName');
                    component.type = metadataType;
                    component.fileName = (String) resultMap.get('fileName');
                    component.lastModifiedDate = (String) resultMap.get('lastModifiedDate');
                    component.lastModifiedByName = (String) resultMap.get('lastModifiedByName');
                    components.add(component);
                }
            } else {
                throw new MetadataException('Failed to retrieve metadata: ' + res.getBody());
            }
        } catch (Exception e) {
            throw new MetadataException('Error calling Metadata API: ' + e.getMessage());
        }

        return components;
    }

    /**
     * @description Deploys metadata to a target Salesforce org
     * @param deploymentId The ID of the Deployment__c record
     * @param zipData Base64 encoded ZIP file containing metadata
     * @return Deployment result
     */
    public static DeploymentResult deployMetadata(Id deploymentId, String zipData) {
        Deployment__c deployment = [
            SELECT Id, Target_Org__c, Target_Org__r.Instance_URL__c,
                   Target_Org__r.Access_Token_Encrypted__c, Target_Org__r.API_Version__c,
                   Check_Only__c, Test_Level__c, Rollback_On_Error__c
            FROM Deployment__c
            WHERE Id = :deploymentId
            LIMIT 1
        ];

        // Construct Metadata API deploy request
        HttpRequest req = new HttpRequest();
        String endpoint = deployment.Target_Org__r.Instance_URL__c +
                         '/services/Soap/m/' + deployment.Target_Org__r.API_Version__c;
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + deployment.Target_Org__r.Access_Token_Encrypted__c);
        req.setHeader('Content-Type', 'text/xml');

        // Build SOAP envelope
        String soapEnvelope = buildDeployRequest(deployment, zipData);
        req.setBody(soapEnvelope);

        DeploymentResult result = new DeploymentResult();

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                // Parse deployment ID from response
                String responseBody = res.getBody();
                result.success = true;
                result.deploymentId = extractDeploymentId(responseBody);

                // Update deployment record
                deployment.Salesforce_Deployment_ID__c = result.deploymentId;
                deployment.Status__c = 'In Progress';
                update deployment;
            } else {
                result.success = false;
                result.errorMessage = 'Deployment failed: ' + res.getBody();
            }
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Error deploying metadata: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Builds SOAP request for metadata deployment
     */
    private static String buildDeployRequest(Deployment__c deployment, String zipData) {
        String soapBody = '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
            '<soapenv:Body>' +
            '<met:deploy>' +
            '<met:ZipFile>' + zipData + '</met:ZipFile>' +
            '<met:DeployOptions>' +
            '<met:checkOnly>' + deployment.Check_Only__c + '</met:checkOnly>' +
            '<met:rollbackOnError>' + deployment.Rollback_On_Error__c + '</met:rollbackOnError>' +
            '<met:testLevel>' + deployment.Test_Level__c + '</met:testLevel>' +
            '</met:DeployOptions>' +
            '</met:deploy>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';

        return soapBody;
    }

    /**
     * @description Extracts deployment ID from SOAP response
     */
    private static String extractDeploymentId(String responseBody) {
        // Simple XML parsing to extract deployment ID
        Integer startIndex = responseBody.indexOf('<id>');
        Integer endIndex = responseBody.indexOf('</id>');

        if (startIndex != -1 && endIndex != -1) {
            return responseBody.substring(startIndex + 4, endIndex);
        }

        return null;
    }

    /**
     * @description Checks the status of a deployment
     * @param deploymentId The Salesforce deployment ID
     * @param orgId The target org ID
     * @return Deployment status
     */
    public static DeploymentStatus checkDeploymentStatus(String deploymentId, Id orgId) {
        Salesforce_Org__c org = [
            SELECT Id, Instance_URL__c, Access_Token_Encrypted__c, API_Version__c
            FROM Salesforce_Org__c
            WHERE Id = :orgId
            LIMIT 1
        ];

        HttpRequest req = new HttpRequest();
        String endpoint = org.Instance_URL__c +
                         '/services/Soap/m/' + org.API_Version__c;
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);
        req.setHeader('Content-Type', 'text/xml');

        String soapBody = buildCheckStatusRequest(deploymentId);
        req.setBody(soapBody);

        DeploymentStatus status = new DeploymentStatus();

        try {
            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                status = parseDeploymentStatus(res.getBody());
            }
        } catch (Exception e) {
            status.status = 'Error';
            status.errorMessage = e.getMessage();
        }

        return status;
    }

    /**
     * @description Builds SOAP request for checking deployment status
     */
    private static String buildCheckStatusRequest(String deploymentId) {
        return '<?xml version="1.0" encoding="utf-8"?>' +
            '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" ' +
            'xmlns:met="http://soap.sforce.com/2006/04/metadata">' +
            '<soapenv:Body>' +
            '<met:checkDeployStatus>' +
            '<met:asyncProcessId>' + deploymentId + '</met:asyncProcessId>' +
            '<met:includeDetails>true</met:includeDetails>' +
            '</met:checkDeployStatus>' +
            '</soapenv:Body>' +
            '</soapenv:Envelope>';
    }

    /**
     * @description Parses deployment status from SOAP response
     */
    private static DeploymentStatus parseDeploymentStatus(String responseBody) {
        DeploymentStatus status = new DeploymentStatus();

        // Parse status
        if (responseBody.contains('<done>true</done>')) {
            status.done = true;
        }

        if (responseBody.contains('<status>Succeeded</status>')) {
            status.status = 'Succeeded';
        } else if (responseBody.contains('<status>Failed</status>')) {
            status.status = 'Failed';
        } else if (responseBody.contains('<status>InProgress</status>')) {
            status.status = 'InProgress';
        }

        // Parse progress
        status.numberComponentsDeployed = extractValue(responseBody, 'numberComponentsDeployed');
        status.numberComponentsTotal = extractValue(responseBody, 'numberComponentsTotal');
        status.numberComponentErrors = extractValue(responseBody, 'numberComponentErrors');

        return status;
    }

    /**
     * @description Helper method to extract value from XML
     */
    private static Integer extractValue(String xml, String tagName) {
        Integer startIndex = xml.indexOf('<' + tagName + '>');
        Integer endIndex = xml.indexOf('</' + tagName + '>');

        if (startIndex != -1 && endIndex != -1) {
            String value = xml.substring(startIndex + tagName.length() + 2, endIndex);
            return Integer.valueOf(value);
        }

        return 0;
    }

    // Inner classes for data structures

    public class MetadataComponent {
        @AuraEnabled public String fullName;
        @AuraEnabled public String type;
        @AuraEnabled public String fileName;
        @AuraEnabled public String lastModifiedDate;
        @AuraEnabled public String lastModifiedByName;
    }

    public class DeploymentResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String deploymentId;
        @AuraEnabled public String errorMessage;
    }

    public class DeploymentStatus {
        @AuraEnabled public Boolean done = false;
        @AuraEnabled public String status;
        @AuraEnabled public Integer numberComponentsDeployed = 0;
        @AuraEnabled public Integer numberComponentsTotal = 0;
        @AuraEnabled public Integer numberComponentErrors = 0;
        @AuraEnabled public String errorMessage;
    }

    public class MetadataException extends Exception {}
}
