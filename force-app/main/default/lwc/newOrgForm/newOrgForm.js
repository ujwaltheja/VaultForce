import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getOAuthAuthorizationUrl from '@salesforce/apex/OrgService.getOAuthAuthorizationUrl';
import exchangeAuthorizationCode from '@salesforce/apex/OrgService.exchangeAuthorizationCode';

export default class NewOrgForm extends LightningElement {
    @track orgName = '';
    @track orgType = '';
    @track instanceUrl = '';
    @track isLoading = false;
    @track showOAuthFlow = false;
    @track errorMessage = '';

    connectedCallback() {
        // Check if we're returning from OAuth callback
        this.checkOAuthCallback();
    }

    handleOrgNameChange(event) {
        this.orgName = event.target.value;
    }

    handleOrgTypeChange(event) {
        this.orgType = event.target.value;
    }

    handleInstanceUrlChange(event) {
        this.instanceUrl = event.target.value;
    }

    get isFormValid() {
        return this.orgName && this.orgType && this.instanceUrl && this.isValidUrl(this.instanceUrl);
    }

    isValidUrl(url) {
        try {
            new URL(url);
            return true;
        } catch {
            return false;
        }
    }

    handleOAuthClick() {
        if (!this.isFormValid) {
            this.errorMessage = 'Please fill in all required fields with valid values.';
            return;
        }

        this.isLoading = true;
        this.errorMessage = '';

        // Get the callback URL (current window origin + callback handler)
        const callbackUrl = window.location.origin + '/oauth/callback';

        getOAuthAuthorizationUrl({ callbackUrl })
            .then(authUrl => {
                // Store org details in session storage for retrieval after OAuth callback
                sessionStorage.setItem('vaultforce_pending_org', JSON.stringify({
                    orgName: this.orgName,
                    orgType: this.orgType,
                    instanceUrl: this.instanceUrl,
                    callbackUrl: callbackUrl
                }));

                this.showOAuthFlow = true;

                // Redirect to OAuth authorization URL
                // Build full authorization URL with instance
                const fullAuthUrl = this.instanceUrl + authUrl;
                window.location.href = fullAuthUrl;
            })
            .catch(error => {
                this.isLoading = false;
                this.errorMessage = error.body?.message || 'Failed to initiate OAuth flow. Please check your OAuth configuration.';
                this.showToast('Error', this.errorMessage, 'error');
            });
    }

    checkOAuthCallback() {
        // Check if we have authorization code in URL
        const urlParams = new URLSearchParams(window.location.search);
        const authCode = urlParams.get('code');
        const error = urlParams.get('error');

        if (error) {
            this.errorMessage = `OAuth Error: ${error}`;
            this.showToast('Authorization Failed', this.errorMessage, 'error');
            return;
        }

        if (authCode) {
            this.isLoading = true;

            // Retrieve stored org details
            const pendingOrgData = sessionStorage.getItem('vaultforce_pending_org');
            if (!pendingOrgData) {
                this.errorMessage = 'Session expired. Please try again.';
                this.isLoading = false;
                return;
            }

            const pendingOrg = JSON.parse(pendingOrgData);

            // Exchange authorization code for tokens
            exchangeAuthorizationCode({
                orgName: pendingOrg.orgName,
                orgType: pendingOrg.orgType,
                authorizationCode: authCode,
                callbackUrl: pendingOrg.callbackUrl,
                instanceUrl: pendingOrg.instanceUrl
            })
                .then(result => {
                    sessionStorage.removeItem('vaultforce_pending_org');
                    this.showToast('Success', `Org "${result.Name}" connected successfully!`, 'success');

                    // Dispatch event to parent component
                    const createEvent = new CustomEvent('orgcreated', {
                        detail: { orgId: result.Id }
                    });
                    this.dispatchEvent(createEvent);

                    // Reset form
                    this.resetForm();
                })
                .catch(error => {
                    this.isLoading = false;
                    this.errorMessage = error.body?.message || 'Failed to complete OAuth flow';
                    this.showToast('Error', this.errorMessage, 'error');
                    sessionStorage.removeItem('vaultforce_pending_org');
                });
        }
    }

    handleCancel() {
        const cancelEvent = new CustomEvent('cancel');
        this.dispatchEvent(cancelEvent);
    }

    resetForm() {
        this.orgName = '';
        this.orgType = '';
        this.instanceUrl = '';
        this.isLoading = false;
        this.showOAuthFlow = false;
        this.errorMessage = '';
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
