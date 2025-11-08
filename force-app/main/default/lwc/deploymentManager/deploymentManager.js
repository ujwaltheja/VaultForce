import { LightningElement, wire, track, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDeployments from '@salesforce/apex/DeploymentService.getDeployments';
import getOrgs from '@salesforce/apex/OrgService.getOrgs';
import createDeployment from '@salesforce/apex/DeploymentService.createDeployment';
import startDeployment from '@salesforce/apex/DeploymentService.startDeployment';
import checkDeploymentStatus from '@salesforce/apex/DeploymentService.checkDeploymentStatus';
import rollbackDeployment from '@salesforce/apex/DeploymentService.rollbackDeployment';

const columns = [
    { label: 'Deployment #', fieldName: 'Name', type: 'text' },
    { label: 'Target Org', fieldName: 'Target_Org__r.Name', type: 'text' },
    { label: 'Type', fieldName: 'Deployment_Type__c', type: 'text' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    {
        label: 'Progress',
        fieldName: 'progress',
        type: 'text',
        cellAttributes: {
            class: { fieldName: 'progressClass' }
        }
    },
    { label: 'Started', fieldName: 'Started_At__c', type: 'date-local' },
    { label: 'Completed', fieldName: 'Completed_At__c', type: 'date-local' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View Details', name: 'view' },
                { label: 'Check Status', name: 'check_status' },
                { label: 'Rollback', name: 'rollback' }
            ]
        }
    }
];

const TEST_LEVEL_OPTIONS = [
    { label: 'Run All Local Tests', value: 'RunLocalTests' },
    { label: 'Run Specified Tests', value: 'RunSpecifiedTests' },
    { label: 'No Tests', value: 'NoTestRun' }
];

const TEST_LEVEL_DESCRIPTIONS = {
    'RunLocalTests': 'Runs all local tests in the org (minimum 75% coverage required)',
    'RunSpecifiedTests': 'Runs specific tests you define (minimum coverage for selected tests required)',
    'NoTestRun': 'No tests are run (for non-production orgs only)'
};

export default class DeploymentManager extends LightningElement {
    @track deployments = [];
    @track columns = columns;
    @track isLoading = false;
    @track showNewDeploymentModal = false;
    @track orgs = [];
    @track deploymentComposerData = null;
    @track deploymentError = '';
    @track isDeploying = false;
    wiredDeploymentsResult;

    @wire(getDeployments)
    wiredDeployments(result) {
        this.wiredDeploymentsResult = result;
        if (result.data) {
            this.deployments = result.data.map(deployment => {
                const completed = deployment.Progress_Completed__c || 0;
                const total = deployment.Progress_Total__c || 0;
                const progress = total > 0 ? `${completed}/${total}` : 'N/A';

                return {
                    ...deployment,
                    'Target_Org__r.Name': deployment.Target_Org__r ? deployment.Target_Org__r.Name : '',
                    progress,
                    progressClass: this.getProgressClass(deployment.Status__c)
                };
            });
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Error loading deployments: ' + result.error.body.message, 'error');
            this.isLoading = false;
        }
    }

    @wire(getOrgs)
    wiredOrgs({ data, error }) {
        if (data) {
            this.orgs = data;
        } else if (error) {
            this.showToast('Error', 'Error loading orgs: ' + error.body.message, 'error');
        }
    }

    get testLevelOptions() {
        return TEST_LEVEL_OPTIONS;
    }

    get testLevelDescription() {
        if (!this.deploymentComposerData) return '';
        return TEST_LEVEL_DESCRIPTIONS[this.deploymentComposerData.testLevel] || '';
    }

    get orgOptions() {
        return this.orgs.map(org => ({
            label: org.Name,
            value: org.Id
        }));
    }

    get componentTypeGroups() {
        if (!this.deploymentComposerData || !this.deploymentComposerData.items) return [];

        const groups = {};
        this.deploymentComposerData.items.forEach(item => {
            if (!groups[item.type]) {
                groups[item.type] = { type: item.type, count: 0 };
            }
            groups[item.type].count++;
        });

        return Object.values(groups);
    }

    get isDeployButtonDisabled() {
        return !this.deploymentComposerData ||
               !this.deploymentComposerData.targetOrgId ||
               !this.deploymentComposerData.testLevel ||
               this.isDeploying;
    }

    getProgressClass(status) {
        switch (status) {
            case 'Completed':
                return 'slds-text-color_success';
            case 'Failed':
                return 'slds-text-color_error';
            case 'In Progress':
                return 'slds-text-color_default';
            default:
                return '';
        }
    }

    handleRowAction(event) {
        try {
            const actionName = event.detail?.action?.name;
            const row = event.detail?.row;

            if (!actionName) {
                console.error('Row action: Action name is undefined', event.detail);
                this.showToast('Error', 'Invalid action configuration', 'error');
                return;
            }

            if (!row || !row.Id) {
                console.error('Row action: Row data is missing', row);
                this.showToast('Error', 'Invalid row selection', 'error');
                return;
            }

            switch (actionName) {
                case 'view':
                    this.viewDeployment(row.Id);
                    break;
                case 'check_status':
                    this.checkStatus(row.Id);
                    break;
                case 'rollback':
                    this.rollback(row.Id);
                    break;
                default:
                    console.warn(`Row action: Unknown action name "${actionName}"`, event.detail);
                    this.showToast('Warning', `Action "${actionName}" is not recognized`, 'warning');
            }
        } catch (error) {
            console.error('Row action handler error:', error);
            this.showToast('Error', 'An unexpected error occurred while processing the action', 'error');
        }
    }

    viewDeployment(deploymentId) {
        const viewEvent = new CustomEvent('viewdeployment', {
            detail: { deploymentId }
        });
        this.dispatchEvent(viewEvent);
    }

    checkStatus(deploymentId) {
        this.isLoading = true;
        checkDeploymentStatus({ deploymentId })
            .then(result => {
                const message = `Status: ${result.status}, Progress: ${result.numberComponentsDeployed}/${result.numberComponentsTotal}`;
                this.showToast('Deployment Status', message, 'info');
                return refreshApex(this.wiredDeploymentsResult);
            })
            .catch(error => {
                this.showToast('Error', 'Error checking status: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    rollback(deploymentId) {
        if (!confirm('Are you sure you want to rollback this deployment?')) {
            return;
        }

        this.isLoading = true;
        rollbackDeployment({ deploymentId })
            .then(() => {
                this.showToast('Success', 'Rollback initiated successfully', 'success');
                return refreshApex(this.wiredDeploymentsResult);
            })
            .catch(error => {
                this.showToast('Error', 'Error rolling back: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleNewDeployment() {
        this.showNewDeploymentModal = true;
        // Initialize deployment composer with default values
        this.deploymentComposerData = {
            targetOrgId: '',
            testLevel: 'RunLocalTests',
            validationOnly: true,
            items: []
        };
        this.deploymentError = '';
    }

    handleCloseModal() {
        this.showNewDeploymentModal = false;
        this.deploymentComposerData = null;
        this.deploymentError = '';
    }

    handleDeployTargetOrgChange(event) {
        if (this.deploymentComposerData) {
            this.deploymentComposerData.targetOrgId = event.detail.value;
        }
    }

    handleTestLevelChange(event) {
        if (this.deploymentComposerData) {
            this.deploymentComposerData.testLevel = event.detail.value;
        }
    }

    handleValidationOnlyChange(event) {
        if (this.deploymentComposerData) {
            this.deploymentComposerData.validationOnly = event.target.checked;
        }
    }

    handleValidateDeployment() {
        if (!this.validateDeploymentInputs()) return;

        this.isDeploying = true;
        this.deploymentError = '';

        // TODO: Call validation Apex method
        this.showToast('Validation', 'Validating deployment...', 'info');
        this.isDeploying = false;
    }

    handleDeploy() {
        if (!this.validateDeploymentInputs()) return;

        if (this.deploymentComposerData.validationOnly) {
            this.showToast('Info', 'Validation-only deployment is enabled', 'info');
        }

        this.isDeploying = true;
        this.deploymentError = '';

        // TODO: Call deploy Apex method with items
        this.showToast('Deployment', 'Deployment started...', 'info');
        this.isDeploying = false;
    }

    validateDeploymentInputs() {
        if (!this.deploymentComposerData.targetOrgId) {
            this.deploymentError = 'Please select a target org';
            return false;
        }

        if (!this.deploymentComposerData.testLevel) {
            this.deploymentError = 'Please select a test level';
            return false;
        }

        if (!this.deploymentComposerData.items || this.deploymentComposerData.items.length === 0) {
            this.deploymentError = 'No components selected for deployment';
            return false;
        }

        return true;
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredDeploymentsResult);
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}
