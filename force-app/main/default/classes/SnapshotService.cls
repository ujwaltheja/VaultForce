/**
 * @description Service class for creating and managing metadata snapshots
 */
public with sharing class SnapshotService {

    /**
     * @description Creates a new metadata snapshot for a Salesforce org
     * @param orgId The ID of the Salesforce_Org__c record
     * @param snapshotType The type of snapshot (Manual, Scheduled, Pre-Deployment, Backup)
     * @return The created Metadata_Snapshot__c record
     */
    @AuraEnabled
    public static Metadata_Snapshot__c createSnapshot(Id orgId, String snapshotType) {
        try {
            // Create snapshot record
            Metadata_Snapshot__c snapshot = new Metadata_Snapshot__c(
                Salesforce_Org__c = orgId,
                Snapshot_Type__c = snapshotType,
                Status__c = 'In Progress',
                Started_At__c = System.now()
            );
            insert snapshot;

            // Log audit
            AuditService.log('Snapshot Created', 'Metadata_Snapshot__c', snapshot.Id);

            // Queue async job to fetch metadata
            System.enqueueJob(new SnapshotQueueable(snapshot.Id));

            return snapshot;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating snapshot: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves snapshot details
     * @param snapshotId The ID of the snapshot
     * @return Snapshot record with related data
     */
    @AuraEnabled(cacheable=true)
    public static Metadata_Snapshot__c getSnapshot(Id snapshotId) {
        try {
            return [
                SELECT Id, Name, Salesforce_Org__c, Salesforce_Org__r.Name,
                       Snapshot_Type__c, Status__c, Component_Count__c,
                       Size_Bytes__c, Started_At__c, Completed_At__c,
                       Error_Message__c, Snapshot_Data__c
                FROM Metadata_Snapshot__c
                WHERE Id = :snapshotId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving snapshot: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all snapshots for a Salesforce org
     * @param orgId The ID of the Salesforce_Org__c record
     * @return List of snapshots
     */
    @AuraEnabled(cacheable=true)
    public static List<Metadata_Snapshot__c> getSnapshotsForOrg(Id orgId) {
        try {
            return [
                SELECT Id, Name, Snapshot_Type__c, Status__c,
                       Component_Count__c, Size_Bytes__c,
                       Started_At__c, Completed_At__c
                FROM Metadata_Snapshot__c
                WHERE Salesforce_Org__c = :orgId
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving snapshots: ' + e.getMessage());
        }
    }

    /**
     * @description Deletes a snapshot
     * @param snapshotId The ID of the snapshot to delete
     */
    @AuraEnabled
    public static void deleteSnapshot(Id snapshotId) {
        try {
            Metadata_Snapshot__c snapshot = [
                SELECT Id FROM Metadata_Snapshot__c WHERE Id = :snapshotId LIMIT 1
            ];
            delete snapshot;

            AuditService.log('Snapshot Deleted', 'Metadata_Snapshot__c', snapshotId);
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting snapshot: ' + e.getMessage());
        }
    }

    /**
     * @description Compares two snapshots and returns the differences
     * @param sourceSnapshotId The source snapshot ID
     * @param targetSnapshotId The target snapshot ID
     * @return Diff result containing added, modified, and deleted components
     */
    @AuraEnabled
    public static DiffResult compareSnapshots(Id sourceSnapshotId, Id targetSnapshotId) {
        try {
            Metadata_Snapshot__c sourceSnapshot = getSnapshot(sourceSnapshotId);
            Metadata_Snapshot__c targetSnapshot = getSnapshot(targetSnapshotId);

            // Parse snapshot data
            Map<String, Object> sourceData = (Map<String, Object>) JSON.deserializeUntyped(
                sourceSnapshot.Snapshot_Data__c
            );
            Map<String, Object> targetData = (Map<String, Object>) JSON.deserializeUntyped(
                targetSnapshot.Snapshot_Data__c
            );

            DiffResult result = new DiffResult();
            result.added = new List<ComponentDiff>();
            result.modified = new List<ComponentDiff>();
            result.deleted = new List<ComponentDiff>();

            // Find added and modified components
            for (String key : sourceData.keySet()) {
                if (!targetData.containsKey(key)) {
                    ComponentDiff diff = new ComponentDiff();
                    diff.componentName = key;
                    diff.changeType = 'Added';
                    result.added.add(diff);
                } else {
                    // Check if modified
                    String sourceHash = String.valueOf(sourceData.get(key));
                    String targetHash = String.valueOf(targetData.get(key));

                    if (sourceHash != targetHash) {
                        ComponentDiff diff = new ComponentDiff();
                        diff.componentName = key;
                        diff.changeType = 'Modified';
                        result.modified.add(diff);
                    }
                }
            }

            // Find deleted components
            for (String key : targetData.keySet()) {
                if (!sourceData.containsKey(key)) {
                    ComponentDiff diff = new ComponentDiff();
                    diff.componentName = key;
                    diff.changeType = 'Deleted';
                    result.deleted.add(diff);
                }
            }

            result.totalChanges = result.added.size() + result.modified.size() + result.deleted.size();

            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error comparing snapshots: ' + e.getMessage());
        }
    }

    // Inner classes

    public class DiffResult {
        @AuraEnabled public List<ComponentDiff> added;
        @AuraEnabled public List<ComponentDiff> modified;
        @AuraEnabled public List<ComponentDiff> deleted;
        @AuraEnabled public Integer totalChanges;
    }

    public class ComponentDiff {
        @AuraEnabled public String componentName;
        @AuraEnabled public String componentType;
        @AuraEnabled public String changeType;
        @AuraEnabled public String sourceContent;
        @AuraEnabled public String targetContent;
    }

    /**
     * @description Queueable class for async snapshot creation
     */
    public class SnapshotQueueable implements Queueable, Database.AllowsCallouts {
        private Id snapshotId;

        public SnapshotQueueable(Id snapshotId) {
            this.snapshotId = snapshotId;
        }

        public void execute(QueueableContext context) {
            try {
                Metadata_Snapshot__c snapshot = [
                    SELECT Id, Salesforce_Org__c, Salesforce_Org__r.Id
                    FROM Metadata_Snapshot__c
                    WHERE Id = :snapshotId
                    LIMIT 1
                ];

                // Define metadata types to retrieve
                List<String> metadataTypes = new List<String>{
                    'ApexClass', 'ApexTrigger', 'LightningComponentBundle',
                    'CustomObject', 'CustomField', 'Flow', 'ValidationRule',
                    'WorkflowRule', 'ApexPage', 'CustomTab'
                };

                // Retrieve metadata
                Map<String, List<MetadataService.MetadataComponent>> metadataMap =
                    MetadataService.retrieveMetadata(snapshot.Salesforce_Org__c, metadataTypes);

                // Convert to JSON and calculate stats
                Integer componentCount = 0;
                Map<String, Object> snapshotData = new Map<String, Object>();

                for (String metadataType : metadataMap.keySet()) {
                    List<MetadataService.MetadataComponent> components = metadataMap.get(metadataType);
                    componentCount += components.size();
                    snapshotData.put(metadataType, components);
                }

                // Update snapshot record
                snapshot.Status__c = 'Completed';
                snapshot.Component_Count__c = componentCount;
                snapshot.Snapshot_Data__c = JSON.serialize(snapshotData);
                snapshot.Size_Bytes__c = snapshot.Snapshot_Data__c.length();
                snapshot.Completed_At__c = System.now();
                update snapshot;

            } catch (Exception e) {
                // Update snapshot with error
                Metadata_Snapshot__c snapshot = [
                    SELECT Id FROM Metadata_Snapshot__c WHERE Id = :snapshotId LIMIT 1
                ];
                snapshot.Status__c = 'Failed';
                snapshot.Error_Message__c = e.getMessage();
                snapshot.Completed_At__c = System.now();
                update snapshot;
            }
        }
    }
}
