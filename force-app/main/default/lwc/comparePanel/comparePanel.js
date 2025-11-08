import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOrgs from '@salesforce/apex/OrgService.getOrgs';
import compareOrgs from '@salesforce/apex/MetadataCompareService.compareOrgs';

const METADATA_TYPES = [
    'ApexClass',
    'ApexTrigger',
    'ApexComponent',
    'ApexPage',
    'LightningComponentBundle',
    'CustomObject',
    'CustomField',
    'CustomApplication',
    'CustomTab',
    'PermissionSet',
    'Profile',
    'Layout',
    'RecordType',
    'ValidationRule',
    'Workflow',
    'FlowDefinition',
    'LightningRecordPage',
    'CustomMetadata',
    'GlobalValueSet',
    'StandardValueSet',
    'NamedCredential',
    'SharingRules'
];

export default class ComparePanel extends LightningElement {
    @track selectedSourceOrgId = '';
    @track selectedTargetOrgId = '';
    @track selectedTypes = new Set(METADATA_TYPES);
    @track selectedTypesMap = {};
    @track typeFilter = '';
    @track orgs = [];
    @track comparisonResults = null;
    @track isComparing = false;
    @track selectedDiffs = new Set();

    connectedCallback() {
        // Initialize selectedTypesMap
        METADATA_TYPES.forEach(type => {
            this.selectedTypesMap[type] = true;
        });
    }

    @wire(getOrgs)
    wiredOrgs({ data, error }) {
        if (data) {
            this.orgs = data;
        } else if (error) {
            this.showToast('Error', 'Failed to load orgs: ' + error.body.message, 'error');
        }
    }

    get orgOptions() {
        return this.orgs.map(org => ({
            label: org.Name,
            value: org.Id
        }));
    }

    get filteredMetadataTypes() {
        const filter = this.typeFilter.toLowerCase();
        return METADATA_TYPES.filter(type => type.toLowerCase().includes(filter));
    }

    get typeCheckboxes() {
        return this.filteredMetadataTypes.map(type => ({
            type,
            label: type,
            checked: this.selectedTypes.has(type)
        }));
    }

    get isCompareDisabled() {
        return !this.selectedSourceOrgId || !this.selectedTargetOrgId || this.isComparing;
    }

    get totalAddedCount() {
        if (!this.comparisonResults || !this.comparisonResults.diffs) return 0;
        return this.comparisonResults.diffs.filter(d => d.action === 'Add').length;
    }

    get totalModifiedCount() {
        if (!this.comparisonResults || !this.comparisonResults.diffs) return 0;
        return this.comparisonResults.diffs.filter(d => d.action === 'Modify').length;
    }

    get totalDeletedCount() {
        if (!this.comparisonResults || !this.comparisonResults.diffs) return 0;
        return this.comparisonResults.diffs.filter(d => d.action === 'Delete').length;
    }

    get allSelectedInTable() {
        if (!this.comparisonResults || !this.comparisonResults.diffs) return false;
        const total = this.comparisonResults.diffs.length;
        return total > 0 && this.selectedDiffs.size === total;
    }

    get selectedDiffsCount() {
        return this.selectedDiffs.size;
    }

    get isDeployButtonDisabled() {
        return this.selectedDiffs.size === 0;
    }

    handleSourceOrgChange(event) {
        this.selectedSourceOrgId = event.detail.value;
    }

    handleTargetOrgChange(event) {
        this.selectedTargetOrgId = event.detail.value;
    }

    handleTypeFilterChange(event) {
        this.typeFilter = event.target.value;
    }

    handleTypeToggle(event) {
        const type = event.target.dataset.type;
        const checked = event.target.checked;

        if (checked) {
            this.selectedTypes.add(type);
        } else {
            this.selectedTypes.delete(type);
        }

        // Update map for template reactivity
        this.selectedTypesMap[type] = checked;
        this.selectedTypesMap = { ...this.selectedTypesMap };
    }

    handleCompare() {
        if (!this.selectedSourceOrgId || !this.selectedTargetOrgId) {
            this.showToast('Validation Error', 'Please select both source and target orgs', 'error');
            return;
        }

        const typesToCompare = Array.from(this.selectedTypes);
        if (typesToCompare.length === 0) {
            this.showToast('Validation Error', 'Please select at least one metadata type', 'error');
            return;
        }

        this.isComparing = true;
        this.comparisonResults = null;

        compareOrgs({
            sourceOrgId: this.selectedSourceOrgId,
            targetOrgId: this.selectedTargetOrgId,
            metadataTypes: typesToCompare
        })
            .then(result => {
                this.comparisonResults = result;

                // Add action classes for styling
                if (result.diffs) {
                    result.diffs.forEach(diff => {
                        switch (diff.action) {
                            case 'Add':
                                diff.actionClass = 'slds-badge slds-badge_success';
                                break;
                            case 'Modify':
                                diff.actionClass = 'slds-badge slds-badge_warning';
                                break;
                            case 'Delete':
                                diff.actionClass = 'slds-badge slds-badge_error';
                                break;
                            default:
                                diff.actionClass = '';
                        }
                    });
                }

                this.showToast(
                    'Comparison Complete',
                    `Found ${result.totalDiffs} differences`,
                    'success'
                );
            })
            .catch(error => {
                this.showToast('Comparison Error', error.body?.message || error.message, 'error');
            })
            .finally(() => {
                this.isComparing = false;
            });
    }

    handleDiffSelection(event) {
        const diffId = event.target.dataset.id;
        const checked = event.target.checked;

        if (checked) {
            this.selectedDiffs.add(diffId);
        } else {
            this.selectedDiffs.delete(diffId);
        }

        // Update diffs array for reactivity
        if (this.comparisonResults && this.comparisonResults.diffs) {
            this.comparisonResults.diffs.forEach(diff => {
                diff.selected = this.selectedDiffs.has(diff.fullName);
            });
            this.comparisonResults.diffs = [...this.comparisonResults.diffs];
        }
    }

    handleSelectAllDiffs(event) {
        const checked = event.target.checked;
        this.selectedDiffs.clear();

        if (checked && this.comparisonResults && this.comparisonResults.diffs) {
            this.comparisonResults.diffs.forEach(diff => {
                this.selectedDiffs.add(diff.fullName);
                diff.selected = true;
            });
            this.comparisonResults.diffs = [...this.comparisonResults.diffs];
        } else if (this.comparisonResults && this.comparisonResults.diffs) {
            this.comparisonResults.diffs.forEach(diff => {
                diff.selected = false;
            });
            this.comparisonResults.diffs = [...this.comparisonResults.diffs];
        }
    }

    handleDeploySelected() {
        if (this.selectedDiffs.size === 0) {
            this.showToast('Selection Error', 'No items selected for deployment', 'error');
            return;
        }

        const selectedItems = this.comparisonResults.diffs.filter(diff =>
            this.selectedDiffs.has(diff.fullName)
        );

        const deployEvent = new CustomEvent('deployrequested', {
            detail: {
                sourceOrgId: this.selectedSourceOrgId,
                targetOrgId: this.selectedTargetOrgId,
                items: selectedItems
            }
        });

        this.dispatchEvent(deployEvent);
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
