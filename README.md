# VaultForce - Salesforce Native Deployment Management Platform

VaultForce is a comprehensive Salesforce-native application for managing metadata deployments, comparisons, backups, and CI/CD automation. Built entirely with Lightning Web Components (LWC) and Apex, VaultForce provides enterprise-grade deployment management capabilities directly within your Salesforce org.

## Overview

VaultForce is the Salesforce-native implementation inspired by SFOps, bringing powerful deployment management capabilities directly into your Salesforce environment. No external infrastructure required!

## Features

### Core Capabilities

- **Org Management**: Connect and manage multiple Salesforce orgs (Production, Sandbox, Developer, Scratch)
- **Metadata Snapshots**: Create and manage metadata snapshots with full component tracking
- **Smart Comparison**: Compare metadata between orgs with detailed diff analysis
- **Deployment Management**: Execute deployments with validation, testing, and rollback capabilities
- **Backup & Restore**: Automatic pre-deployment backups with one-click rollback
- **CI/CD Pipelines**: Configure automated deployment pipelines with approval gates
- **Audit Logging**: Comprehensive audit trail for compliance and tracking
- **Real-time Monitoring**: Track deployment progress and status in real-time

### Architecture Highlights

- **100% Salesforce Native**: Built entirely with LWC and Apex
- **Secure**: Uses encrypted fields for sensitive data storage
- **Scalable**: Queueable Apex for async processing
- **Observable**: Built-in audit logging and activity tracking
- **User-Friendly**: Modern LWC interface with Lightning Design System

## Project Structure

```
VaultForce/
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/              # Apex service classes
│           │   ├── MetadataService.cls       # Metadata API integration
│           │   ├── DeploymentService.cls     # Deployment management
│           │   ├── SnapshotService.cls       # Snapshot operations
│           │   ├── OrgService.cls            # Org connection management
│           │   └── AuditService.cls          # Audit logging
│           ├── lwc/                  # Lightning Web Components
│           │   ├── orgList/                  # Org list component
│           │   ├── deploymentManager/        # Deployment manager
│           │   └── vaultForceDashboard/      # Main dashboard
│           └── objects/              # Custom Objects
│               ├── Salesforce_Org__c/        # Org connections
│               ├── Metadata_Snapshot__c/     # Snapshots
│               ├── Deployment__c/            # Deployments
│               ├── Deployment_Component__c/  # Deployment components
│               ├── Pipeline__c/              # CI/CD pipelines
│               └── Audit_Log__c/             # Audit logs
├── sfdx-project.json
└── README.md
```

## Data Model

### Custom Objects

#### Salesforce_Org__c
Stores connected Salesforce org information:
- Org Name, Type, Instance URL
- OAuth tokens (encrypted)
- Connection status
- Last connected timestamp

#### Metadata_Snapshot__c
Stores metadata snapshots:
- Snapshot type (Manual, Scheduled, Pre-Deployment, Backup)
- Component count and size
- Snapshot data (JSON)
- Status and timestamps

#### Deployment__c
Stores deployment records:
- Source and target orgs
- Deployment type and status
- Progress tracking
- Test level configuration
- Backup snapshot reference

#### Deployment_Component__c
Stores individual components in a deployment:
- Component type and name
- Component status
- Error messages
- File size

#### Pipeline__c
Stores CI/CD pipeline configurations:
- Source and target orgs
- Trigger type (Manual, Scheduled, Git Webhook, API)
- Auto-deploy and approval settings
- Notification configuration

#### Audit_Log__c
Stores audit trail:
- Action performed
- Object type and ID
- User information
- Timestamp and details

## Key Apex Classes

### MetadataService
Handles all Metadata API interactions:
- `retrieveMetadata()` - Retrieves metadata from connected orgs
- `deployMetadata()` - Deploys metadata to target orgs
- `checkDeploymentStatus()` - Monitors deployment progress
- Supports SOAP API integration for metadata operations

### DeploymentService
Manages deployment lifecycle:
- `createDeployment()` - Creates new deployments
- `startDeployment()` - Initiates deployment execution
- `checkDeploymentStatus()` - Checks deployment progress
- `rollbackDeployment()` - Rolls back failed deployments
- `cancelDeployment()` - Cancels in-progress deployments

### SnapshotService
Handles metadata snapshots:
- `createSnapshot()` - Creates new snapshots
- `getSnapshotsForOrg()` - Retrieves org snapshots
- `compareSnapshots()` - Compares two snapshots
- `deleteSnapshot()` - Deletes snapshots
- Async processing with Queueable Apex

### OrgService
Manages org connections:
- `createOrg()` - Connects new Salesforce orgs
- `getOrgs()` - Retrieves all connected orgs
- `testConnection()` - Tests org connectivity
- `refreshToken()` - Refreshes OAuth tokens
- `deleteOrg()` - Removes org connections

### AuditService
Provides audit logging:
- `log()` - Creates audit log entries
- `getAuditLogs()` - Retrieves audit logs
- Automatic tracking of all operations

## Lightning Web Components

### vaultForceDashboard
Main dashboard component showing:
- Connected orgs statistics
- Deployment success rates
- Recent deployments
- Recent activity feed

### orgList
Manages Salesforce org connections:
- Display connected orgs in datatable
- Test connections
- Create snapshots
- Delete orgs

### deploymentManager
Manages deployments:
- View all deployments
- Check deployment status
- Initiate rollbacks
- Monitor progress

## Installation

### Prerequisites
- Salesforce org (Developer, Sandbox, or Production)
- Salesforce CLI installed
- Git installed

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/ujwaltheja/VaultForce.git
   cd VaultForce
   ```

2. **Authenticate to your Salesforce org**
   ```bash
   sfdx auth:web:login -a myOrgAlias
   ```

3. **Deploy to your org**
   ```bash
   sfdx force:source:deploy -p force-app -u myOrgAlias
   ```

4. **Assign permission set** (if created)
   ```bash
   sfdx force:user:permset:assign -n VaultForce_Admin -u myOrgAlias
   ```

5. **Open your org**
   ```bash
   sfdx force:org:open -u myOrgAlias
   ```

## Usage

### Connecting a Salesforce Org

1. Navigate to the VaultForce app
2. Click "New Org" on the Org List component
3. Enter org details:
   - Org Name
   - Org Type (Production, Sandbox, Developer, Scratch)
   - Instance URL
   - Username
4. Complete OAuth authentication flow
5. Org will appear in the connected orgs list

### Creating a Snapshot

1. From the Org List, click the action menu on an org
2. Select "Create Snapshot"
3. Choose snapshot type:
   - Manual: On-demand snapshot
   - Scheduled: Automated snapshot
   - Pre-Deployment: Before deployment
   - Backup: Full backup
4. Snapshot will be created asynchronously
5. View snapshot details when complete

### Executing a Deployment

1. Click "New Deployment" in Deployment Manager
2. Configure deployment:
   - Select target org
   - Choose deployment type (Validation, Deploy, Quick Deploy)
   - Set test level (NoTestRun, RunLocalTests, RunAllTests)
   - Enable/disable rollback on error
3. Select components to deploy
4. Review and start deployment
5. Monitor progress in real-time
6. View results and logs

### Rolling Back a Deployment

1. Locate the deployment in Deployment Manager
2. Click action menu and select "Rollback"
3. Confirm rollback operation
4. VaultForce will restore from pre-deployment snapshot
5. Monitor rollback progress

### Setting Up a CI/CD Pipeline

1. Navigate to Pipelines
2. Click "New Pipeline"
3. Configure:
   - Pipeline name
   - Source org
   - Target org
   - Trigger type (Manual, Scheduled, Git Webhook)
   - Auto-deploy settings
   - Approval requirements
   - Test configuration
4. Save pipeline
5. Pipeline will execute based on trigger type

## Security Considerations

### Data Encryption
- OAuth tokens stored in encrypted text fields
- Access tokens and refresh tokens encrypted at rest
- Platform encryption recommended for production

### Access Control
- Implement permission sets for role-based access
- Object-level security via sharing settings
- Field-level security for sensitive fields

### API Security
- All API callouts use secure HTTPS
- OAuth 2.0 for org authentication
- Token refresh automation

## Monitoring & Observability

### Audit Logging
- All operations logged to Audit_Log__c
- Tracks user, timestamp, action, and details
- 7-year retention for compliance

### Real-time Monitoring
- Deployment progress tracking
- Component-level status
- Error messages and stack traces

### Activity Feed
- Recent deployments
- Recent snapshots
- System events

## Best Practices

### Deployment Management
1. Always create pre-deployment snapshots
2. Run validation deployments first
3. Use appropriate test levels
4. Monitor deployment progress
5. Review deployment logs

### Snapshot Management
1. Create regular scheduled snapshots
2. Clean up old snapshots periodically
3. Document snapshot purposes
4. Maintain backup snapshots

### Org Management
1. Test connections regularly
2. Refresh tokens before expiry
3. Document org purposes
4. Monitor org status

## Limitations

### Salesforce Platform Limits
- Governor limits apply to all Apex operations
- Async processing subject to queueable limits
- API callout limits (max 100 per transaction)
- Heap size limits for large metadata

### Metadata API Limitations
- Some metadata types may not be retrievable
- Large deployments may timeout
- Deployment size limits apply

## Roadmap

### Phase 1 (Current)
- [x] Basic org management
- [x] Snapshot creation
- [x] Deployment management
- [x] Audit logging
- [x] LWC components

### Phase 2 (Planned)
- [ ] Visual diff viewer
- [ ] Advanced component selection
- [ ] Scheduled deployments
- [ ] Email notifications
- [ ] Mobile-optimized UI

### Phase 3 (Future)
- [ ] Git integration
- [ ] Conflict resolution
- [ ] Deployment templates
- [ ] Analytics dashboard
- [ ] API access

## Migrated from SFOps

VaultForce is inspired by and migrated from [SFOps](https://github.com/ujwaltheja/SFOps), a comprehensive Node.js-based SaaS platform. Key architectural changes:

### Original SFOps Architecture
- Node.js/TypeScript backend
- React frontend
- PostgreSQL database
- Redis caching
- Temporal workflow engine
- HashiCorp Vault
- Kubernetes deployment

### VaultForce Architecture
- 100% Salesforce native
- Lightning Web Components
- Apex backend
- Salesforce database
- Platform events
- Encrypted custom fields
- Queueable/Batch Apex

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

Copyright © 2024 VaultForce. All rights reserved.

## Support

- **Documentation**: See this README and inline code documentation
- **Issues**: https://github.com/ujwaltheja/VaultForce/issues
- **Questions**: Open a GitHub discussion

## Acknowledgments

- Inspired by [SFOps](https://github.com/ujwaltheja/SFOps)
- Built with Salesforce Platform
- Lightning Web Components
- Salesforce Metadata API
- Lightning Design System

## Technical Details

### Apex Classes

| Class | Purpose | Key Methods |
|-------|---------|-------------|
| MetadataService | Metadata API integration | retrieveMetadata, deployMetadata, checkDeploymentStatus |
| DeploymentService | Deployment management | createDeployment, startDeployment, rollbackDeployment |
| SnapshotService | Snapshot operations | createSnapshot, compareSnapshots, deleteSnapshot |
| OrgService | Org management | createOrg, testConnection, refreshToken |
| AuditService | Audit logging | log, getAuditLogs |

### Lightning Web Components

| Component | Purpose | Features |
|-----------|---------|----------|
| vaultForceDashboard | Main dashboard | Statistics, recent activity, deployment status |
| orgList | Org management | List orgs, test connections, create snapshots |
| deploymentManager | Deployment management | Create deployments, monitor progress, rollback |

### API Integration

VaultForce integrates with:
- **Salesforce Metadata API**: For metadata retrieval and deployment
- **Salesforce Tooling API**: For component-level operations
- **Salesforce REST API**: For general org operations
- **OAuth 2.0**: For secure org authentication

## Version History

### v1.0.0 (Current)
- Initial release
- Core org management
- Snapshot creation
- Deployment management
- Audit logging
- LWC dashboard and components

---

**Built with ❤️ by the VaultForce Team**
