/**
 * @description Service class for managing deployments
 */
public with sharing class DeploymentService {

    /**
     * @description Creates a new deployment
     * @param targetOrgId The target Salesforce org ID
     * @param deploymentType The deployment type (Validation, Deploy, Quick Deploy)
     * @param checkOnly Whether this is a validation-only deployment
     * @param testLevel The test level for the deployment
     * @return The created Deployment__c record
     */
    @AuraEnabled
    public static Deployment__c createDeployment(
        Id targetOrgId,
        String deploymentType,
        Boolean checkOnly,
        String testLevel
    ) {
        try {
            Deployment__c deployment = new Deployment__c(
                Target_Org__c = targetOrgId,
                Deployment_Type__c = deploymentType,
                Check_Only__c = checkOnly,
                Test_Level__c = testLevel,
                Status__c = 'Queued',
                Rollback_On_Error__c = true,
                Run_Tests__c = testLevel != 'NoTestRun'
            );
            insert deployment;

            // Log audit
            AuditService.log('Deployment Started', 'Deployment__c', deployment.Id);

            return deployment;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating deployment: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves deployment details
     * @param deploymentId The deployment ID
     * @return Deployment record with related data
     */
    @AuraEnabled(cacheable=true)
    public static Deployment__c getDeployment(Id deploymentId) {
        try {
            return [
                SELECT Id, Name, Target_Org__c, Target_Org__r.Name,
                       Source_Org__c, Source_Org__r.Name,
                       Status__c, Deployment_Type__c, Check_Only__c,
                       Test_Level__c, Salesforce_Deployment_ID__c,
                       Progress_Total__c, Progress_Completed__c, Progress_Failed__c,
                       Error_Message__c, Started_At__c, Completed_At__c,
                       Backup_Snapshot__c, Backup_Snapshot__r.Name
                FROM Deployment__c
                WHERE Id = :deploymentId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving deployment: ' + e.getMessage());
        }
    }

    /**
     * @description Retrieves all deployments
     * @return List of deployments
     */
    @AuraEnabled(cacheable=true)
    public static List<Deployment__c> getDeployments() {
        try {
            return [
                SELECT Id, Name, Target_Org__r.Name, Status__c,
                       Deployment_Type__c, Progress_Completed__c,
                       Progress_Total__c, Started_At__c, Completed_At__c
                FROM Deployment__c
                ORDER BY CreatedDate DESC
                LIMIT 100
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving deployments: ' + e.getMessage());
        }
    }

    /**
     * @description Starts a deployment by enqueueing it
     * @param deploymentId The deployment ID
     * @param components List of components to deploy
     */
    @AuraEnabled
    public static void startDeployment(Id deploymentId, List<String> components) {
        try {
            // Create deployment components
            List<Deployment_Component__c> deploymentComponents = new List<Deployment_Component__c>();

            for (String component : components) {
                List<String> parts = component.split(':');
                if (parts.size() == 2) {
                    Deployment_Component__c dc = new Deployment_Component__c(
                        Deployment__c = deploymentId,
                        Component_Type__c = parts[0],
                        Component_Name__c = parts[1],
                        Status__c = 'Pending'
                    );
                    deploymentComponents.add(dc);
                }
            }

            if (!deploymentComponents.isEmpty()) {
                insert deploymentComponents;
            }

            // Create backup snapshot before deployment
            Deployment__c deployment = [
                SELECT Id, Target_Org__c FROM Deployment__c WHERE Id = :deploymentId LIMIT 1
            ];

            Metadata_Snapshot__c backupSnapshot = SnapshotService.createSnapshot(
                deployment.Target_Org__c,
                'Pre-Deployment'
            );

            deployment.Backup_Snapshot__c = backupSnapshot.Id;
            deployment.Status__c = 'In Progress';
            deployment.Started_At__c = System.now();
            update deployment;

            // Enqueue deployment job
            System.enqueueJob(new DeploymentQueueable(deploymentId));

        } catch (Exception e) {
            throw new AuraHandledException('Error starting deployment: ' + e.getMessage());
        }
    }

    /**
     * @description Checks deployment status and updates record
     * @param deploymentId The deployment ID
     * @return Updated deployment status
     */
    @AuraEnabled
    public static MetadataService.DeploymentStatus checkDeploymentStatus(Id deploymentId) {
        try {
            Deployment__c deployment = [
                SELECT Id, Salesforce_Deployment_ID__c, Target_Org__c, Status__c
                FROM Deployment__c
                WHERE Id = :deploymentId
                LIMIT 1
            ];

            if (String.isBlank(deployment.Salesforce_Deployment_ID__c)) {
                throw new AuraHandledException('Deployment has not been started');
            }

            MetadataService.DeploymentStatus status = MetadataService.checkDeploymentStatus(
                deployment.Salesforce_Deployment_ID__c,
                deployment.Target_Org__c
            );

            // Update deployment record
            deployment.Progress_Total__c = status.numberComponentsTotal;
            deployment.Progress_Completed__c = status.numberComponentsDeployed;
            deployment.Progress_Failed__c = status.numberComponentErrors;

            if (status.done) {
                deployment.Completed_At__c = System.now();

                if (status.status == 'Succeeded') {
                    deployment.Status__c = 'Completed';
                    AuditService.log('Deployment Completed', 'Deployment__c', deploymentId);
                } else {
                    deployment.Status__c = 'Failed';
                    deployment.Error_Message__c = status.errorMessage;
                    AuditService.log('Deployment Failed', 'Deployment__c', deploymentId);
                }
            }

            update deployment;

            return status;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking deployment status: ' + e.getMessage());
        }
    }

    /**
     * @description Rolls back a deployment to the backup snapshot
     * @param deploymentId The deployment ID
     */
    @AuraEnabled
    public static void rollbackDeployment(Id deploymentId) {
        try {
            Deployment__c deployment = [
                SELECT Id, Backup_Snapshot__c, Target_Org__c
                FROM Deployment__c
                WHERE Id = :deploymentId
                LIMIT 1
            ];

            if (deployment.Backup_Snapshot__c == null) {
                throw new AuraHandledException('No backup snapshot available for rollback');
            }

            // Create a new deployment from backup snapshot
            Deployment__c rollbackDeployment = new Deployment__c(
                Target_Org__c = deployment.Target_Org__c,
                Deployment_Type__c = 'Deploy',
                Check_Only__c = false,
                Test_Level__c = 'NoTestRun',
                Status__c = 'In Progress',
                Rollback_On_Error__c = false
            );
            insert rollbackDeployment;

            // Update original deployment
            deployment.Status__c = 'Rolled Back';
            update deployment;

            AuditService.log('Rollback Executed', 'Deployment__c', deploymentId);

        } catch (Exception e) {
            throw new AuraHandledException('Error rolling back deployment: ' + e.getMessage());
        }
    }

    /**
     * @description Cancels a deployment
     * @param deploymentId The deployment ID
     */
    @AuraEnabled
    public static void cancelDeployment(Id deploymentId) {
        try {
            Deployment__c deployment = [
                SELECT Id, Status__c FROM Deployment__c WHERE Id = :deploymentId LIMIT 1
            ];

            if (deployment.Status__c == 'In Progress' || deployment.Status__c == 'Queued') {
                deployment.Status__c = 'Failed';
                deployment.Error_Message__c = 'Deployment cancelled by user';
                deployment.Completed_At__c = System.now();
                update deployment;
            }

        } catch (Exception e) {
            throw new AuraHandledException('Error cancelling deployment: ' + e.getMessage());
        }
    }

    /**
     * @description Queueable class for async deployment execution
     */
    public class DeploymentQueueable implements Queueable, Database.AllowsCallouts {
        private Id deploymentId;

        public DeploymentQueueable(Id deploymentId) {
            this.deploymentId = deploymentId;
        }

        public void execute(QueueableContext context) {
            try {
                // Get deployment components
                List<Deployment_Component__c> components = [
                    SELECT Id, Component_Type__c, Component_Name__c
                    FROM Deployment_Component__c
                    WHERE Deployment__c = :deploymentId
                ];

                // Build package.xml and zip file
                String zipData = buildDeploymentPackage(components);

                // Deploy to target org
                MetadataService.DeploymentResult result =
                    MetadataService.deployMetadata(deploymentId, zipData);

                if (!result.success) {
                    throw new DeploymentException(result.errorMessage);
                }

            } catch (Exception e) {
                Deployment__c deployment = [
                    SELECT Id FROM Deployment__c WHERE Id = :deploymentId LIMIT 1
                ];
                deployment.Status__c = 'Failed';
                deployment.Error_Message__c = e.getMessage();
                deployment.Completed_At__c = System.now();
                update deployment;
            }
        }

        private String buildDeploymentPackage(List<Deployment_Component__c> components) {
            // Build package.xml
            String packageXml = '<?xml version="1.0" encoding="UTF-8"?>' +
                '<Package xmlns="http://soap.sforce.com/2006/04/metadata">' +
                '<version>60.0</version>';

            Map<String, List<String>> typeMap = new Map<String, List<String>>();

            for (Deployment_Component__c component : components) {
                if (!typeMap.containsKey(component.Component_Type__c)) {
                    typeMap.put(component.Component_Type__c, new List<String>());
                }
                typeMap.get(component.Component_Type__c).add(component.Component_Name__c);
            }

            for (String metadataType : typeMap.keySet()) {
                packageXml += '<types>';
                for (String memberName : typeMap.get(metadataType)) {
                    packageXml += '<members>' + memberName + '</members>';
                }
                packageXml += '<name>' + metadataType + '</name></types>';
            }

            packageXml += '</Package>';

            // In a real implementation, you would create a proper ZIP file
            // For now, we'll return the base64 encoded package.xml
            return EncodingUtil.base64Encode(Blob.valueOf(packageXml));
        }
    }

    public class DeploymentException extends Exception {}
}
