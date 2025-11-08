import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const STAGES = ['Development', 'QA', 'UAT', 'Production'];

export default class PipelineBoard extends LightningElement {
    @track stages = STAGES;
    @track artifacts = [];
    @track stageData = [];
    @track isLoading = false;
    @track errorMessage = '';

    connectedCallback() {
        this.loadArtifacts();
    }

    loadArtifacts() {
        this.isLoading = true;
        this.errorMessage = '';

        // TODO: Call Apex method to fetch pipeline artifacts
        // For now, we'll use mock data for demonstration

        setTimeout(() => {
            this.artifacts = [
                {
                    Id: '1',
                    Name: 'Release-2024-01',
                    Stage__c: 'Development',
                    Status__c: 'In Progress',
                    componentCount: 12,
                    CreatedDate: new Date(2024, 10, 1),
                    formattedCreatedDate: '11/1/2024'
                },
                {
                    Id: '2',
                    Name: 'Release-2024-02',
                    Stage__c: 'QA',
                    Status__c: 'Validation Passed',
                    componentCount: 8,
                    CreatedDate: new Date(2024, 10, 5),
                    formattedCreatedDate: '11/5/2024'
                },
                {
                    Id: '3',
                    Name: 'Release-2024-03',
                    Stage__c: 'UAT',
                    Status__c: 'Pending Approval',
                    componentCount: 15,
                    CreatedDate: new Date(2024, 10, 8),
                    formattedCreatedDate: '11/8/2024'
                },
                {
                    Id: '4',
                    Name: 'Release-2024-04',
                    Stage__c: 'Production',
                    Status__c: 'Deployed',
                    componentCount: 20,
                    CreatedDate: new Date(2024, 9, 28),
                    formattedCreatedDate: '10/28/2024'
                }
            ];

            // Add status class and canPromote flag to each artifact
            this.artifacts.forEach((artifact, index) => {
                artifact.statusClass = this.getStatusClass(artifact.Status__c);
                artifact.statusBadgeClass = this.getStatusBadgeClass(artifact.Status__c);
                const stageIndex = this.stages.indexOf(artifact.Stage__c);
                artifact.canPromote = stageIndex < this.stages.length - 1 &&
                    (artifact.Status__c === 'Validation Passed' || artifact.Status__c === 'Approved');
            });

            // Organize artifacts by stage
            this.stageData = this.stages.map(stage => ({
                name: stage,
                count: this.artifacts.filter(a => a.Stage__c === stage).length,
                artifacts: this.artifacts.filter(a => a.Stage__c === stage),
                columnClass: this.getColumnClass(stage),
                headerClass: this.getHeaderClass(stage)
            }));

            this.isLoading = false;
        }, 1000);
    }

    get stageStats() {
        return this.stageData.map(stage => ({
            stage: stage.name,
            count: stage.count
        }));
    }

    getStatusClass(status) {
        switch (status) {
            case 'In Progress':
                return 'slds-badge slds-badge_lightest';
            case 'Validation Passed':
                return 'slds-badge slds-badge_success';
            case 'Pending Approval':
                return 'slds-badge slds-badge_warning';
            case 'Deployed':
                return 'slds-badge slds-badge_success';
            case 'Failed':
                return 'slds-badge slds-badge_error';
            default:
                return 'slds-badge slds-badge_lightest';
        }
    }

    getStatusBadgeClass(status) {
        const baseClass = 'artifact-status-badge';
        switch (status) {
            case 'In Progress':
                return `${baseClass} in-progress`;
            case 'Validation Passed':
            case 'Deployed':
                return `${baseClass} ready`;
            case 'Pending Approval':
                return `${baseClass} in-progress`;
            case 'Failed':
                return `${baseClass} failed`;
            default:
                return baseClass;
        }
    }

    getColumnClass(stage) {
        return 'kanban-column';
    }

    getHeaderClass(stage) {
        const baseClass = 'column-header';
        const stageLower = stage.toLowerCase().replace(' ', '-');
        return `${baseClass} ${stageLower}`;
    }

    handlePromote(event) {
        const artifactId = event.target.dataset.artifactId;
        const stage = event.target.dataset.stage;

        if (!confirm(`Promote artifact to next stage?`)) {
            return;
        }

        // TODO: Call Apex method to promote artifact
        this.showToast('Promotion', `Artifact promoted from ${stage}`, 'success');
        this.loadArtifacts();
    }

    handleViewArtifact(event) {
        const artifactId = event.target.dataset.artifactId;

        const viewEvent = new CustomEvent('artifactselected', {
            detail: { artifactId }
        });
        this.dispatchEvent(viewEvent);
    }

    handleRefresh() {
        this.loadArtifacts();
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
