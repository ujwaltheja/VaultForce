# OAuth Implementation for Salesforce Org Connections

## Problem Statement

The original VaultForce implementation did not have functional OAuth authentication for connecting to external Salesforce orgs. The `createOrg()` method only created org records without capturing OAuth tokens, making it impossible to:

- Authenticate with external Salesforce orgs
- Retrieve metadata or deploy changes
- Manage org connections securely

## Solution Overview

VaultForce now implements a complete OAuth 2.0 Web Server Flow for Salesforce org connections:

1. **User initiates org connection** via the "New Org" button
2. **User provides org details** (name, type, instance URL)
3. **OAuth authorization URL is generated** with proper scope and callback URL
4. **User is redirected to Salesforce** for authorization
5. **After authorization, Salesforce redirects back** with authorization code
6. **VaultForce exchanges the code for tokens** securely
7. **Tokens are stored encrypted** in the org record
8. **Org can now be used** for metadata operations

## Implementation Details

### Backend Changes (Apex)

#### 1. Updated `OrgService.createOrg()` (Lines 17-46)

**Before:**
- Only accepted basic org info (name, type, instanceUrl, username)
- Created org record without tokens
- Org was "connected" but not authenticated

**After:**
- Now accepts OAuth tokens as parameters: `accessToken`, `refreshToken`
- Stores encrypted tokens in org record
- Sets `Last_Connected__c` timestamp
- Logs audit entry for the connection

```apex
public static Salesforce_Org__c createOrg(
    String orgName,
    String orgType,
    String instanceUrl,
    String username,
    String accessToken,      // New parameter
    String refreshToken      // New parameter
)
```

#### 2. New Method: `getOAuthAuthorizationUrl()` (Lines 53-72)

Generates the Salesforce OAuth authorization URL that users are redirected to.

**Features:**
- Includes proper OAuth parameters (client_id, redirect_uri, scope)
- Uses `api` and `refresh_token` scopes for full functionality
- Returns just the path portion, allowing dynamic instance URL

#### 3. New Method: `exchangeAuthorizationCode()` (Lines 84-150)

Handles the OAuth callback by exchanging the authorization code for tokens.

**Process:**
1. Validates authorization code is present
2. Makes POST request to `/services/oauth2/token` endpoint
3. Exchanges code for `access_token` and `refresh_token`
4. Fetches user info using the access token
5. Creates org record with tokens via `createOrg()`

**Error Handling:**
- Validates authorization code presence
- Checks token response validity
- Retrieves username from OAuth userinfo endpoint
- Provides detailed error messages

#### 4. Enhanced `testConnection()` (Lines 240-309)

**Previous Issue:**
- Assumed tokens existed
- Displayed generic errors when tokens were missing

**Improvements:**
- Checks for token existence before API calls
- Returns helpful message if credentials not configured
- Detects 401 (Unauthorized) responses
- Attempts automatic token refresh on 401
- Sets org status to "Not Authenticated" if tokens missing
- Sets org status to "Token Expired" if refresh fails

#### 5. Enhanced `refreshToken()` (Lines 316-371)

**Previous Issue:**
- Could fail silently with malformed requests
- Didn't validate token existence before attempting refresh

**Improvements:**
- Validates refresh token exists
- URL-encodes all sensitive parameters
- Handles missing tokens gracefully
- Logs refresh events in audit trail
- Provides detailed error messages
- Validates access token in response

#### 6. New Method: `validateOrgCredentials()` (Lines 378-406)

Allows checking if an org has valid OAuth credentials configured.

**Returns:**
- `isValid`: Whether org has access token
- `hasAccessToken`: Whether access token exists
- `hasRefreshToken`: Whether refresh token exists
- `status`: Current org connection status
- `message`: Human-readable status message

**Usage Example:**
```apex
OrgService.OrgValidationResult validation =
    OrgService.validateOrgCredentials(orgId);
if (!validation.isValid) {
    // Prompt user to reconnect org
}
```

#### 7. New Inner Class: `OrgValidationResult` (Lines 458-464)

Wrapper class for org validation responses with `@AuraEnabled` fields for LWC communication.

### Frontend Changes (LWC)

#### 1. New Component: `newOrgForm` (newOrgForm.html, newOrgForm.js)

**Purpose:** Guides users through OAuth org connection process

**HTML Features:**
- Form with fields for org details
- Org name input
- Org type dropdown (Production, Sandbox, Developer, Scratch)
- Instance URL input with validation
- Clear OAuth flow explanation
- Authorization button
- Error message display

**JavaScript Features:**
- Form validation (all fields required, valid URL)
- OAuth URL generation
- Session storage for org details during OAuth flow
- Authorization code capture from callback
- Token exchange initiation
- Error handling with user-friendly messages
- Success event dispatch to parent component

**Usage Flow:**
1. User fills in org details
2. Clicks "Authorize with OAuth"
3. Redirected to target Salesforce org
4. User authorizes VaultForce
5. Redirected back with authorization code
6. Code exchanged for tokens
7. Org created in VaultForce

#### 2. Updated Component: `orgList`

**Changes:**
- Integrated `newOrgForm` component in modal
- Added modal visibility tracking
- Added `showNewOrgModal` tracked property
- Updated "New Org" button to show modal instead of dispatching event
- Added event handlers:
  - `handleCloseNewOrgModal()` - Close modal
  - `handleOrgCreated()` - Handle successful org creation and refresh list
- Fixed empty state template to check `orgs.length` instead of `orgs`
- Added large modal container for better form display

**Modal Improvements:**
- Properly styled with SLDS classes
- Close button in header
- Backdrop overlay
- Accessible dialog markup

## Security Considerations

### Token Encryption

VaultForce uses Salesforce's built-in field-level encryption:
- Access tokens stored in `EncryptedText` field `Access_Token_Encrypted__c`
- Refresh tokens stored in `EncryptedText` field `Refresh_Token_Encrypted__c`
- Tokens are encrypted at rest in the database
- Encryption keys are managed by Salesforce

### Token Handling

1. **Never logged**: Tokens are never logged or stored in logs
2. **HTTPS only**: All OAuth communication uses HTTPS
3. **Automatic refresh**: Expired tokens are automatically refreshed
4. **Revocation**: Disconnecting an org removes the tokens

### OAuth Configuration

1. **Client ID/Secret**: Should be stored securely (see OAUTH_SETUP.md)
2. **Callback URL**: Must be registered in Connected App
3. **Scopes**: Limited to necessary permissions (`api` and `refresh_token`)

## Error Handling

The implementation includes comprehensive error handling:

| Error | Cause | Resolution |
|-------|-------|-----------|
| "OAuth credentials not configured" | Client ID/Secret not set | Update `getClientId()` and `getClientSecret()` |
| "Authorization code is missing" | OAuth flow cancelled | User must retry the OAuth flow |
| "OAuth token exchange failed" | Invalid code, redirect_uri mismatch | Check Connected App configuration |
| "Connection failed" | Network error or invalid endpoint | Verify instance URL is correct |
| "Token expired and refresh failed" | Refresh token invalid/expired | User must reconnect the org |

## Testing the Implementation

### Test 1: OAuth Authorization Flow
1. Go to VaultForce org
2. Click "Connected Salesforce Orgs" > "New Org"
3. Fill in test org details (use a real Salesforce org instance)
4. Click "Authorize with OAuth"
5. Verify redirect to Salesforce login
6. Authorize the connection
7. Verify redirect back to VaultForce
8. Verify org created with success message

### Test 2: Token Verification
1. After org creation, click "Test Connection"
2. Should see "Connection successful" message
3. Last_Connected__c should be updated

### Test 3: Token Refresh
1. Wait for access token to expire (or use test/developer org)
2. Run "Test Connection" again
3. Should see "Token refreshed and connection established" message
4. Or detect expired token and prompt for reconnection

### Test 4: Error Handling
1. Delete the access token from the org record
2. Try "Test Connection"
3. Should see "OAuth credentials not configured. Please reconnect this org."

## Files Modified/Created

### Created:
- `force-app/main/default/lwc/newOrgForm/newOrgForm.html`
- `force-app/main/default/lwc/newOrgForm/newOrgForm.js`
- `force-app/main/default/lwc/newOrgForm/newOrgForm.js-meta.xml`
- `OAUTH_SETUP.md` (Setup instructions)
- `OAUTH_IMPLEMENTATION.md` (This file)

### Modified:
- `force-app/main/default/classes/OrgService.cls`
  - Enhanced `createOrg()` method
  - Added `getOAuthAuthorizationUrl()` method
  - Added `exchangeAuthorizationCode()` method
  - Enhanced `testConnection()` method
  - Enhanced `refreshToken()` method
  - Added `validateOrgCredentials()` method
  - Added `OrgValidationResult` inner class

- `force-app/main/default/lwc/orgList/orgList.html`
  - Added new org modal dialog
  - Integrated newOrgForm component
  - Fixed empty state template

- `force-app/main/default/lwc/orgList/orgList.js`
  - Added `showNewOrgModal` tracked property
  - Added `handleNewOrg()` implementation
  - Added `handleCloseNewOrgModal()` handler
  - Added `handleOrgCreated()` handler

## Next Steps

### Short Term:
1. Configure OAuth credentials (see OAUTH_SETUP.md)
2. Create a Connected App in your VaultForce org
3. Deploy the changes
4. Test org connection with a real Salesforce org

### Medium Term:
1. Implement org reconnection/re-authentication flow
2. Add bulk org import feature
3. Implement automatic token refresh before expiration

### Long Term:
1. Create custom Apex REST endpoint for OAuth callback (more control)
2. Implement organization-wide OAuth configuration
3. Add support for JWT bearer token flow for service accounts
4. Implement org credential rotation policies

## References

- Salesforce OAuth Documentation: https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_oauth.htm
- Connected Apps: https://help.salesforce.com/s/articleView?id=sf.connected_app_overview.htm
- REST API Basics: https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/
