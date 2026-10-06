import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getStatuses from '@salesforce/apex/PpcCredentialHealthController.getStatuses';
import probeNow from '@salesforce/apex/PpcCredentialHealthController.probeNow';

const POLL_INTERVAL_MS = 3000;
const POLL_TIMEOUT_MS = 45000;
const AUTO_REFRESH_MS = 60000;
const STATUS_LABELS = {
    Healthy: 'Healthy',
    Unhealthy: 'Unhealthy',
    Other_Error: 'Other Error',
    Unknown: 'Unknown'
};

export default class PpcCredentialHealth extends LightningElement {
    @track rows = [];
    isLoading = true;
    isProbing = false;
    errorMessage;
    lastRefreshed;
    pollTimer;
    autoRefreshTimer;
    probeStartedAt;

    connectedCallback() {
        this.refreshStatuses();
        this.autoRefreshTimer = setInterval(() => {
            if (!this.isProbing) {
                this.refreshStatuses();
            }
        }, AUTO_REFRESH_MS);
    }

    disconnectedCallback() {
        this.clearPollTimer();
        if (this.autoRefreshTimer) {
            clearInterval(this.autoRefreshTimer);
        }
    }

    get hasRows() {
        return !this.isLoading && this.rows && this.rows.length > 0;
    }

    get showEmpty() {
        return !this.isLoading && (!this.rows || this.rows.length === 0);
    }

    get probeDisabled() {
        return this.isProbing || this.isLoading;
    }

    get lastRefreshedLabel() {
        return this.lastRefreshed ? this.formatAge(this.lastRefreshed) : 'never';
    }

    get displayRows() {
        return (this.rows || []).map((row) => {
            const status = row.status || 'Unknown';
            return {
                ...row,
                statusLabel: STATUS_LABELS[status] || status,
                httpStatusDisplay: row.httpStatusCode != null ? String(row.httpStatusCode) : '—',
                lastCheckedLabel: row.lastChecked ? this.formatAge(row.lastChecked) : 'never',
                responseTimeLabel: row.responseTimeMs != null ? `${row.responseTimeMs} ms` : '—',
                consecutiveFailures: row.consecutiveFailures != null ? row.consecutiveFailures : 0,
                cardClass: `status-card status-card_${this.statusModifier(status)}${row.isStale ? ' is-stale' : ''}`,
                badgeClass: `status-badge status-badge_${this.statusModifier(status)}`
            };
        });
    }

    statusModifier(status) {
        switch (status) {
            case 'Healthy':
                return 'healthy';
            case 'Unhealthy':
                return 'unhealthy';
            case 'Other_Error':
                return 'other';
            default:
                return 'unknown';
        }
    }

    handleProbeNow() {
        this.isProbing = true;
        this.errorMessage = null;
        this.probeStartedAt = Date.now();
        probeNow()
            .then(() => {
                this.toast('Health check started', 'Named credentials are being probed.', 'success');
                this.startPolling();
            })
            .catch((error) => {
                this.isProbing = false;
                this.errorMessage = this.reduceError(error);
                this.toast('Could not start health check', this.errorMessage, 'error');
            });
    }

    startPolling() {
        this.clearPollTimer();
        this.pollTimer = setInterval(() => {
            this.refreshStatuses(true);
        }, POLL_INTERVAL_MS);
    }

    refreshStatuses(fromPoll) {
        getStatuses()
            .then((result) => {
                this.rows = result || [];
                this.lastRefreshed = new Date();
                this.errorMessage = null;
                if (fromPoll) {
                    this.maybeStopPolling();
                }
            })
            .catch((error) => {
                this.errorMessage = this.reduceError(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    maybeStopPolling() {
        const timedOut = Date.now() - this.probeStartedAt > POLL_TIMEOUT_MS;
        const allCheckedAfterProbe = this.rows.length > 0 && this.rows.every((row) => {
            if (!row.lastChecked) {
                return false;
            }
            return new Date(row.lastChecked).getTime() >= this.probeStartedAt - 5000;
        });
        if (timedOut || allCheckedAfterProbe) {
            this.isProbing = false;
            this.clearPollTimer();
        }
    }

    clearPollTimer() {
        if (this.pollTimer) {
            clearInterval(this.pollTimer);
            this.pollTimer = undefined;
        }
    }

    formatAge(value) {
        const date = value instanceof Date ? value : new Date(value);
        const minutes = Math.floor((Date.now() - date.getTime()) / 60000);
        if (Number.isNaN(minutes) || minutes < 0) {
            return 'just now';
        }
        if (minutes < 1) {
            return 'just now';
        }
        if (minutes === 1) {
            return '1 minute ago';
        }
        if (minutes < 60) {
            return `${minutes} minutes ago`;
        }
        const hours = Math.floor(minutes / 60);
        if (hours === 1) {
            return '1 hour ago';
        }
        if (hours < 24) {
            return `${hours} hours ago`;
        }
        return date.toLocaleString();
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }
        if (Array.isArray(error?.body) && error.body[0]?.message) {
            return error.body[0].message;
        }
        return error?.message || 'Unexpected error';
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}