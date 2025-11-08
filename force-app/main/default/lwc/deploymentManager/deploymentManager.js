import { LightningElement, wire, track, api } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDeployments from '@salesforce/apex/DeploymentService.getDeployments';
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

export default class DeploymentManager extends LightningElement {
    @track deployments = [];
    @track columns = columns;
    @track isLoading = false;
    @track showNewDeploymentModal = false;
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
        const actionName = event.detail.action.name;
        const row = event.detail.row;

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
    }

    handleCloseModal() {
        this.showNewDeploymentModal = false;
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
