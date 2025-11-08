import { LightningElement, api } from 'lwc';

export default class VaultForceNotification extends LightningElement {
    @api variant = 'info'; // success, error, warning, info
    @api title = '';
    @api message = '';
    @api duration = 5000; // Auto-dismiss after 5 seconds
    @api dismissible;

    showNotification = true;
    timeoutId;

    connectedCallback() {
        if (this.duration > 0) {
            this.timeoutId = setTimeout(() => {
                this.handleDismiss();
            }, this.duration);
        }
    }

    disconnectedCallback() {
        if (this.timeoutId) {
            clearTimeout(this.timeoutId);
        }
    }

    get containerClass() {
        return `notification-container notification-${this.variant}`;
    }

    get iconName() {
        const icons = {
            success: '✓',
            error: '✕',
            warning: '⚠',
            info: 'ℹ'
        };
        return icons[this.variant] || icons.info;
    }

    get progressBarClass() {
        return `notification-progress notification-progress-${this.variant}`;
    }

    handleDismiss() {
        this.showNotification = false;
        // Dispatch custom event to parent
        this.dispatchEvent(new CustomEvent('dismiss'));
    }
}
