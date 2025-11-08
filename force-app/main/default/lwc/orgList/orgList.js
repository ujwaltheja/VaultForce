import { LightningElement, wire, track } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgs from '@salesforce/apex/OrgService.getOrgs';
import deleteOrg from '@salesforce/apex/OrgService.deleteOrg';
import testConnection from '@salesforce/apex/OrgService.testConnection';

const columns = [
    { label: 'Org Name', fieldName: 'Name', type: 'text' },
    { label: 'Type', fieldName: 'Org_Type__c', type: 'text' },
    { label: 'Username', fieldName: 'Username__c', type: 'text' },
    { label: 'Instance URL', fieldName: 'Instance_URL__c', type: 'url' },
    { label: 'Status', fieldName: 'Status__c', type: 'text' },
    { label: 'Last Connected', fieldName: 'Last_Connected__c', type: 'date-local' },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'View', name: 'view' },
                { label: 'Test Connection', name: 'test_connection' },
                { label: 'Create Snapshot', name: 'create_snapshot' },
                { label: 'Delete', name: 'delete' }
            ]
        }
    }
];

export default class OrgList extends LightningElement {
    @track orgs = [];
    @track columns = columns;
    @track isLoading = false;
    wiredOrgsResult;

    @wire(getOrgs)
    wiredOrgs(result) {
        this.wiredOrgsResult = result;
        if (result.data) {
            this.orgs = result.data;
            this.isLoading = false;
        } else if (result.error) {
            this.showToast('Error', 'Error loading orgs: ' + result.error.body.message, 'error');
            this.isLoading = false;
        }
    }

    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        switch (actionName) {
            case 'view':
                this.viewOrg(row.Id);
                break;
            case 'test_connection':
                this.testOrgConnection(row.Id);
                break;
            case 'create_snapshot':
                this.createSnapshot(row.Id);
                break;
            case 'delete':
                this.deleteOrg(row.Id);
                break;
        }
    }

    viewOrg(orgId) {
        const selectEvent = new CustomEvent('orgselect', {
            detail: { orgId }
        });
        this.dispatchEvent(selectEvent);
    }

    testOrgConnection(orgId) {
        this.isLoading = true;
        testConnection({ orgId })
            .then(result => {
                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                } else {
                    this.showToast('Error', result.message, 'error');
                }
                this.isLoading = false;
                return refreshApex(this.wiredOrgsResult);
            })
            .catch(error => {
                this.showToast('Error', 'Error testing connection: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    createSnapshot(orgId) {
        const snapshotEvent = new CustomEvent('createsnapshot', {
            detail: { orgId }
        });
        this.dispatchEvent(snapshotEvent);
    }

    deleteOrg(orgId) {
        if (!confirm('Are you sure you want to delete this org connection?')) {
            return;
        }

        this.isLoading = true;
        deleteOrg({ orgId })
            .then(() => {
                this.showToast('Success', 'Org connection deleted successfully', 'success');
                return refreshApex(this.wiredOrgsResult);
            })
            .catch(error => {
                this.showToast('Error', 'Error deleting org: ' + error.body.message, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleNewOrg() {
        const newOrgEvent = new CustomEvent('neworg');
        this.dispatchEvent(newOrgEvent);
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredOrgsResult);
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
