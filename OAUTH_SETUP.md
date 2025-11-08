# OAuth Configuration for VaultForce

This guide explains how to configure OAuth authentication for connecting external Salesforce orgs to VaultForce.

## Prerequisites

- Administrator access to your VaultForce org
- The ability to create Connected Apps in your VaultForce org
- The instance URL of the target org(s) you want to connect

## Step 1: Create a Connected App in Your VaultForce Org

This is the app that will manage OAuth for connecting external orgs.

### Instructions:

1. In your VaultForce org, go to **Setup**
2. Search for **App Manager** and open it
3. Click **New Connected App**
4. Fill in the following details:
   - **Connected App Name**: `VaultForce OAuth`
   - **API Name**: `VaultForce_OAuth` (auto-filled)
   - **Contact Email**: Your email address

5. Under **API (Enable OAuth Settings)**:
   - Check **Enable OAuth Settings**
   - Set **Callback URL** to your VaultForce instance URL + `/oauth/callback`
     - Example: `https://yourinstance.lightning.force.com/oauth/callback`

6. Under **Selected OAuth Scopes**, add these scopes:
   - `api` - Provides access to the default, full, and visualforce scopes
   - `refresh_token` - Enables OAuth refresh token flow
   - `web` - Provides access to the web scope

   After selecting each scope, click **Add** to move it to the "Selected OAuth Scopes" list.

7. Click **Save**

8. After saving, you'll see the **Consumer Key** and **Consumer Secret**
   - Click **Reveal** next to Consumer Secret to display it

## Step 2: Create and Configure Custom Metadata Type for OAuth

VaultForce requires a Custom Metadata Type (`OAuth_Config__mdt`) for storing OAuth credentials securely. Follow the steps below to create it manually in your Salesforce org.

### Step 2A: Create the Custom Metadata Type

1. In your VaultForce org, go to **Setup**

2. Search for **Custom Metadata Types** and click **Create**

3. Fill in the metadata type details:
   - **Label**: `OAuth Config`
   - **Plural Label**: `OAuth Configs`
   - **API Name**: `OAuth_Config` (auto-fills as `OAuth_Config__mdt`)
   - **Visibility**: `Public`

4. Click **Save**

5. You'll be redirected to add custom fields. Click **New Field** and add the following fields:

   **Field 1 - Client ID:**
   - **Label**: `Client ID`
   - **API Name**: `Client_ID` (auto-fills as `Client_ID__c`)
   - **Type**: `Text`
   - **Length**: `255`
   - **Required**: Check this box
   - Click **Save**

   **Field 2 - Client Secret:**
   - **Label**: `Client Secret`
   - **API Name**: `Client_Secret` (auto-fills as `Client_Secret__c`)
   - **Type**: `Text`
   - **Length**: `255`
   - **Required**: Check this box
   - Click **Save**

   **Field 3 - Is Configured:**
   - **Label**: `Is Configured`
   - **API Name**: `Is_Configured` (auto-fills as `Is_Configured__c`)
   - **Type**: `Checkbox`
   - **Default Value**: Unchecked
   - Click **Save**

### Step 2B: Create the Default Configuration Record

1. Go back to **Custom Metadata Types** in Setup

2. Click on **OAuth Config**

3. Click **Manage Records**

4. Click **New** to create a new record

5. Fill in the values:
   - **Label**: `Default Config`
   - **API Name**: `Default_Config` (auto-fills)
   - **Client ID**: Paste your **Consumer Key** from the Connected App
   - **Client Secret**: Paste your **Consumer Secret** from the Connected App
   - **Is Configured**: Check this box to enable OAuth

6. Click **Save**

### Step 2C: Deploy VaultForce Code

Now deploy the VaultForce code:
```bash
sfdx project deploy start -d force-app
```

The deployment will succeed and OrgService will be able to access your OAuth credentials.

### Step 2D: Alternative - Using Named Credentials (Optional for Production)

For enhanced security in production, you can use Salesforce Named Credentials instead of Custom Metadata Type:

1. In your VaultForce org, go to **Setup**

2. Search for **Named Credentials** and click **New Named Credential**

3. Fill in the following:
   - **Label**: `SalesforceOAuth`
   - **Name**: `SalesforceOAuth`
   - **URL**: `https://login.salesforce.com`
   - **Identity Type**: `Named Principal`
   - **Authentication Protocol**: `OAuth 2.0`
   - **Authentication Provider**: Create a new auth provider (see instructions below)

4. Create an Authentication Provider:
   - Go to **Setup** → **Authentication Providers**
   - Click **New**
   - **Provider Type**: `Salesforce`
   - **Name**: `SalesforceOAuthProvider`
   - **Client ID**: Your Consumer Key
   - **Client Secret**: Your Consumer Secret
   - **Authorize Endpoint URL**: `https://login.salesforce.com/services/oauth2/authorize`
   - **Token Endpoint URL**: `https://login.salesforce.com/services/oauth2/token`

5. To use Named Credentials, modify `OrgService.cls` to query the Named Credential instead of Custom Metadata Type (future enhancement)

## Step 3: Validate OAuth Configuration

To verify your OAuth setup is correct before testing:

1. In your VaultForce app, use the **Developer Console** or a custom LWC component to call:
```apex
OrgService.OAuthValidationResult result = OrgService.validateOAuthConfiguration();
System.debug('OAuth Config Status: ' + result.configStatus);
System.debug('Message: ' + result.message);
```

2. Expected result if properly configured:
```
OAuth Config Status: CONFIGURED
Message: OAuth is properly configured.
```

3. If you see errors, refer to the troubleshooting section below.

## Step 4: Test the OAuth Flow

1. Navigate to the VaultForce app

2. Click **Connected Salesforce Orgs** > **New Org**

3. Fill in the org details:
   - **Org Name**: Give your org a friendly name
   - **Org Type**: Select the type (Production, Sandbox, Developer, Scratch)
   - **Instance URL**: The Salesforce instance URL (e.g., https://login.salesforce.com)

4. Click **Authorize with OAuth**

5. You'll be redirected to the target org to authorize
   - Log in if prompted
   - Review and approve the connection request

6. After authorization, you'll be returned to VaultForce with an active org connection

## Step 5: Verify the Connection

1. In the **Connected Salesforce Orgs** list, find your newly connected org
2. Click **Test Connection** from the row actions
3. You should see a success message confirming the connection is working

## Troubleshooting

### OAuth Configuration Not Found
**Error**: "OAuth_Config__mdt custom metadata type not found. Follow OAUTH_SETUP.md Step 2A to create it."
- **Cause**: The Custom Metadata Type hasn't been created in your org yet
- **Solution**: Follow Step 2A in OAUTH_SETUP.md to manually create the OAuth_Config custom metadata type in Setup

### OAuth Credentials Not Configured (Missing Values)
**Error**: "OAuth Client ID is not configured" or "OAuth Client Secret is not configured"
- **Cause**: The values are missing or still have placeholder text (UPDATE_WITH_...)
- **Solution**:
  1. Go to Setup → Custom Metadata Types → OAuth Config → Manage Records
  2. Edit the **Default_Config** record
  3. Verify both Client ID and Client Secret fields have your actual Consumer Key and Secret values
  4. Ensure the **Is Configured** checkbox is marked

### OAuth Error: "Invalid client id"
- **Cause**: The Client ID in the Custom Metadata Type doesn't match your Connected App
- **Solution**:
  1. Copy the Consumer Key from your Connected App in Salesforce Setup
  2. Paste it exactly into the Custom Metadata Type Client ID field
  3. Note: Consumer Keys are case-sensitive

### OAuth Error: "Invalid client secret"
- **Cause**: The Client Secret in the Custom Metadata Type doesn't match your Connected App
- **Solution**:
  1. Go to your Connected App and click "Reveal" next to Consumer Secret
  2. Copy the full secret exactly
  3. Paste it into the Custom Metadata Type Client Secret field
  4. Note: Consumer Secrets are case-sensitive and very long

### OAuth Error: "invalid_redirect_uri"
- **Cause**: The Callback URL in your Connected App doesn't match the expected redirect
- **Solution**:
  1. Verify the Callback URL in your Connected App is: `https://yourinstance.lightning.force.com/oauth/callback`
  2. Replace `yourinstance` with your actual Salesforce instance name
  3. Ensure HTTPS is used (not HTTP)

### Connection Test Failed: "OAuth credentials not configured"
- **Cause**: The org record has no access token stored
- **Solution**:
  1. Click "New Org" to reconnect the org with OAuth
  2. Go through the full OAuth authorization flow
  3. Ensure the browser doesn't block the redirect from Salesforce

### validateOAuthConfiguration() Returns ERROR Status
**Status**: ERROR
- **Cause**: The OAuth_Config__mdt custom metadata type doesn't exist
- **Solution**: Follow Step 2A-2B in OAUTH_SETUP.md to create the Custom Metadata Type and Default_Config record

### validateOAuthConfiguration() Returns MISSING Status
**Status**: MISSING
- **Cause**: The Default_Config record doesn't exist in the OAuth_Config custom metadata type
- **Solution**: Follow Step 2B in OAUTH_SETUP.md to create the Default_Config record

### validateOAuthConfiguration() Returns MISSING_CLIENT_ID
**Status**: MISSING_CLIENT_ID
- **Cause**: Client ID field is empty or has placeholder text
- **Solution**: Update the Custom Metadata Type record with your actual Consumer Key

### validateOAuthConfiguration() Returns MISSING_CLIENT_SECRET
**Status**: MISSING_CLIENT_SECRET
- **Cause**: Client Secret field is empty or has placeholder text
- **Solution**: Update the Custom Metadata Type record with your actual Consumer Secret

### validateOAuthConfiguration() Returns NOT_FLAGGED
**Status**: NOT_FLAGGED
- **Cause**: Both credentials exist but the "Is Configured" checkbox is not marked
- **Solution**: Open the Custom Metadata Type record and check the "Is Configured" checkbox

### "Token refresh failed"
- **Cause**: The refresh token may have expired
- **Solution**: Reconnect the org by clicking "New Org" and going through the OAuth flow again

## Security Best Practices

### Current Implementation (Custom Metadata Type)

VaultForce uses **Custom Metadata Type** for OAuth configuration, which provides:
- **Code-free credential storage**: No secrets in git/version control
- **Org-specific configuration**: Each org can have different credentials
- **Audit trail**: Changes to credentials are logged in Salesforce audit logs
- **Access control**: Field-level security can be applied to credential fields

### For Enhanced Security in Production:

1. **Use Named Credentials** (Optional upgrade):
   - More secure than Custom Metadata Type for sensitive environments
   - Credentials are never visible in UI after creation
   - See "Method B: Using Named Credentials" in Step 2

2. **Restrict Custom Metadata Access**:
   - Limit who can edit OAuth_Config custom metadata type
   - Only system administrators should modify credentials
   - Use field-level security to restrict visibility

3. **Environment-Specific Credentials**:
   - Use different Connected Apps for Development, Staging, and Production
   - Update the OAuth_Config metadata type for each environment before deploying

4. **Token Encryption**:
   - VaultForce automatically encrypts org connection tokens using the `EncryptedText` field type
   - OAuth credentials in Custom Metadata Type are stored as plain Text
   - For additional security, use Named Credentials or Encrypted Custom Fields

5. **Token Expiration & Refresh**:
   - VaultForce detects token expiration (401 responses) and automatically refreshes
   - Tokens are refreshed on-demand when needed
   - Consider implementing batch jobs for proactive token refresh

6. **Revoke Tokens on Disconnect**:
   - When disconnecting an org, VaultForce removes the tokens from the database
   - To fully revoke, also revoke in the target org:
     1. Log in to the target Salesforce org
     2. Go to Setup → Session Settings → OAuth Tokens
     3. Revoke any tokens for VaultForce

7. **Audit & Monitoring**:
   - VaultForce logs all org connections and disconnections in the Audit_Log__c object
   - Review audit logs regularly for suspicious activity
   - Monitor failed token refresh attempts

## Additional Resources

- [Salesforce OAuth Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_oauth.htm)
- [Connected Apps](https://help.salesforce.com/s/articleView?id=sf.connected_app_overview.htm)
- [OAuth Token Lifecycle](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_oauth_token_flow.htm)
