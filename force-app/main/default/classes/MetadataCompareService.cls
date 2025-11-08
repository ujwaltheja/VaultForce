/**
 * @description Service for comparing metadata between two Salesforce orgs
 */
public with sharing class MetadataCompareService {

    /**
     * @description Compares metadata between source and target orgs
     * @param sourceOrgId Source org ID
     * @param targetOrgId Target org ID
     * @param metadataTypes List of metadata types to compare (e.g., 'ApexClass', 'LightningComponentBundle')
     * @return Comparison result with diffs grouped by type
     */
    @AuraEnabled
    public static ComparisonResult compareOrgs(Id sourceOrgId, Id targetOrgId, List<String> metadataTypes) {
        ComparisonResult result = new ComparisonResult();
        try {
            // Validate orgs
            Salesforce_Org__c sourceOrg = getOrg(sourceOrgId);
            Salesforce_Org__c targetOrg = getOrg(targetOrgId);

            if (sourceOrg == null || targetOrg == null) {
                throw new AuraHandledException('Invalid source or target org');
            }

            // Validate tokens
            validateOrgTokens(sourceOrg);
            validateOrgTokens(targetOrg);

            // Fetch metadata from both orgs
            Map<String, MetadataItem> sourceMetadata = fetchOrgMetadata(sourceOrg, metadataTypes);
            Map<String, MetadataItem> targetMetadata = fetchOrgMetadata(targetOrg, metadataTypes);

            // Compute diffs
            result.diffs = computeDiffs(sourceMetadata, targetMetadata, metadataTypes);
            result.sourceOrgId = sourceOrgId;
            result.targetOrgId = targetOrgId;
            result.sourceOrgName = sourceOrg.Name;
            result.targetOrgName = targetOrg.Name;
            result.metadataTypesQueried = metadataTypes;
            result.totalDiffs = result.diffs.size();
            result.success = true;

            // Log comparison
            Map<String, Object> details = new Map<String, Object>{
                'sourceOrgName' => sourceOrg.Name,
                'targetOrgName' => targetOrg.Name,
                'differences' => result.totalDiffs,
                'metadataTypes' => String.join(metadataTypes, ', ')
            };
            AuditService.log('Metadata Comparison', 'Salesforce_Org__c', sourceOrgId, details);

        } catch (AuraHandledException e) {
            result.success = false;
            result.errorMessage = e.getMessage();
        } catch (Exception e) {
            result.success = false;
            result.errorMessage = 'Comparison failed: ' + e.getMessage();
        }

        return result;
    }

    /**
     * @description Fetches metadata from an org via REST API
     * @param org The org to fetch from
     * @param metadataTypes Types to fetch
     * @return Map of metadata name to MetadataItem
     */
    private static Map<String, MetadataItem> fetchOrgMetadata(Salesforce_Org__c org, List<String> metadataTypes) {
        Map<String, MetadataItem> metadata = new Map<String, MetadataItem>();

        // For MVP, simulate metadata fetch from REST API
        // In production, would call org's /services/data/v60.0/metadata/describe endpoint
        // and then list/{type} endpoints for each metadata type

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(org.Instance_URL__c + '/services/data/v60.0/metadata/describe');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> metadataObjects = (List<Object>) response.get('metadataObjects');

                if (metadataObjects != null) {
                    for (Object obj : metadataObjects) {
                        Map<String, Object> metaObj = (Map<String, Object>) obj;
                        String xmlName = (String) metaObj.get('xmlName');

                        if (metadataTypes.contains(xmlName)) {
                            // Fetch members of this type
                            List<String> members = fetchMetadataMembers(org, xmlName);
                            for (String member : members) {
                                MetadataItem item = new MetadataItem();
                                item.type = xmlName;
                                item.fullName = member;
                                metadata.put(xmlName + ':' + member, item);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to fetch metadata from org: ' + e.getMessage());
        }

        return metadata;
    }

    /**
     * @description Fetches members of a specific metadata type
     * @param org The org to fetch from
     * @param metadataType The metadata type
     * @return List of member names
     */
    private static List<String> fetchMetadataMembers(Salesforce_Org__c org, String metadataType) {
        List<String> members = new List<String>();

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(org.Instance_URL__c + '/services/data/v60.0/metadata/list?type=' + metadataType);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + org.Access_Token_Encrypted__c);
            req.setTimeout(30000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                List<Object> results = (List<Object>) JSON.deserializeUntyped(res.getBody());
                if (results != null) {
                    for (Object result : results) {
                        Map<String, Object> item = (Map<String, Object>) result;
                        members.add((String) item.get('fullName'));
                    }
                }
            }
        } catch (Exception e) {
            // Return empty list if type fetch fails
        }

        return members;
    }

    /**
     * @description Computes differences between source and target metadata
     * @param sourceMetadata Source org metadata
     * @param targetMetadata Target org metadata
     * @param metadataTypes Types to include in diff
     * @return List of MetadataDiff items
     */
    private static List<MetadataDiff> computeDiffs(
        Map<String, MetadataItem> sourceMetadata,
        Map<String, MetadataItem> targetMetadata,
        List<String> metadataTypes
    ) {
        List<MetadataDiff> diffs = new List<MetadataDiff>();

        // Added or modified in source
        for (String key : sourceMetadata.keySet()) {
            MetadataItem sourceItem = sourceMetadata.get(key);

            if (!targetMetadata.containsKey(key)) {
                // Added in source
                MetadataDiff diff = new MetadataDiff();
                diff.type = sourceItem.type;
                diff.fullName = sourceItem.fullName;
                diff.action = 'Add';
                diff.selected = true;
                diffs.add(diff);
            } else {
                // Modified (in this MVP, we'll assume modified if it exists in both)
                MetadataDiff diff = new MetadataDiff();
                diff.type = sourceItem.type;
                diff.fullName = sourceItem.fullName;
                diff.action = 'Modify';
                diff.selected = true;
                diffs.add(diff);
            }
        }

        // Deleted from source (exists in target but not source)
        for (String key : targetMetadata.keySet()) {
            if (!sourceMetadata.containsKey(key)) {
                MetadataItem targetItem = targetMetadata.get(key);
                MetadataDiff diff = new MetadataDiff();
                diff.type = targetItem.type;
                diff.fullName = targetItem.fullName;
                diff.action = 'Delete';
                diff.selected = false;
                diffs.add(diff);
            }
        }

        return diffs;
    }

    /**
     * @description Gets org by ID
     * @param orgId The org ID
     * @return The org record
     */
    private static Salesforce_Org__c getOrg(Id orgId) {
        try {
            return [
                SELECT Id, Name, Instance_URL__c, Access_Token_Encrypted__c, Status__c
                FROM Salesforce_Org__c
                WHERE Id = :orgId
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    /**
     * @description Validates that org has necessary OAuth tokens
     * @param org The org to validate
     */
    private static void validateOrgTokens(Salesforce_Org__c org) {
        if (String.isBlank(org.Access_Token_Encrypted__c)) {
            throw new AuraHandledException(
                'Org "' + org.Name + '" does not have valid OAuth credentials. Please reconnect it.'
            );
        }
    }

    // Inner classes

    public class ComparisonResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public List<MetadataDiff> diffs;
        @AuraEnabled public String sourceOrgName;
        @AuraEnabled public String targetOrgName;
        @AuraEnabled public Id sourceOrgId;
        @AuraEnabled public Id targetOrgId;
        @AuraEnabled public List<String> metadataTypesQueried;
        @AuraEnabled public Integer totalDiffs;
        @AuraEnabled public String errorMessage;
    }

    public class MetadataDiff {
        @AuraEnabled public String type;
        @AuraEnabled public String fullName;
        @AuraEnabled public String action; // 'Add', 'Modify', 'Delete'
        @AuraEnabled public Boolean selected;
        @AuraEnabled public String apiName; // For sObjects/fields
    }

    public class MetadataItem {
        public String type;
        public String fullName;
        public String apiName;
    }
}
