import { LightningElement, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgs from '@salesforce/apex/OrgService.getOrgs';
import getDeployments from '@salesforce/apex/DeploymentService.getDeployments';
import getRecentAuditLogs from '@salesforce/apex/AuditService.getRecentAuditLogs';

export default class VaultForceDashboard extends LightningElement {
    @track stats = {
        totalOrgs: 0,
        activeOrgs: 0,
        totalDeployments: 0,
        successfulDeployments: 0,
        failedDeployments: 0,
        inProgressDeployments: 0
    };

    @track recentDeployments = [];
    @track recentAuditLogs = [];
    @track isLoading = true;

    @wire(getOrgs)
    wiredOrgs({ data, error }) {
        if (data) {
            this.stats.totalOrgs = data.length;
            this.stats.activeOrgs = data.filter(org => org.Status__c === 'Active').length;
        } else if (error) {
            this.showToast('Error', 'Error loading orgs: ' + error.body.message, 'error');
        }
    }

    @wire(getDeployments)
    wiredDeployments({ data, error }) {
        if (data) {
            this.stats.totalDeployments = data.length;
            this.stats.successfulDeployments = data.filter(d => d.Status__c === 'Completed').length;
            this.stats.failedDeployments = data.filter(d => d.Status__c === 'Failed').length;
            this.stats.inProgressDeployments = data.filter(d => d.Status__c === 'In Progress').length;

            this.recentDeployments = data.slice(0, 5).map(deployment => ({
                ...deployment,
                targetOrgName: deployment.Target_Org__r ? deployment.Target_Org__r.Name : 'N/A',
                statusClass: this.getStatusClass(deployment.Status__c)
            }));

            this.isLoading = false;
        } else if (error) {
            this.showToast('Error', 'Error loading deployments: ' + error.body.message, 'error');
            this.isLoading = false;
        }
    }

    @wire(getRecentAuditLogs)
    wiredAuditLogs({ data, error }) {
        if (data) {
            this.recentAuditLogs = data.slice(0, 10);
        } else if (error) {
            this.showToast('Error', 'Error loading audit logs: ' + error.body.message, 'error');
        }
    }

    getStatusClass(status) {
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

    get successRate() {
        if (this.stats.totalDeployments === 0) return '0%';
        const rate = (this.stats.successfulDeployments / this.stats.totalDeployments) * 100;
        return rate.toFixed(1) + '%';
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
