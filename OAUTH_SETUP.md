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

## Step 2: Configure OAuth Credentials in OrgService

Once you have your Consumer Key and Secret, you need to update the `OrgService.cls` file:

1. In your VaultForce project, open `force-app/main/default/classes/OrgService.cls`

2. Find the `getClientId()` method (around line 412) and replace:
```apex
String clientId = 'YOUR_OAUTH_CLIENT_ID_HERE';
```
with:
```apex
String clientId = 'YOUR_CONSUMER_KEY_HERE';
```

3. Find the `getClientSecret()` method (around line 440) and replace:
```apex
String clientSecret = 'YOUR_OAUTH_CLIENT_SECRET_HERE';
```
with:
```apex
String clientSecret = 'YOUR_CONSUMER_SECRET_HERE';
```

4. Replace:
   - `YOUR_CONSUMER_KEY_HERE` with the **Consumer Key** from your Connected App
   - `YOUR_CONSUMER_SECRET_HERE` with the **Consumer Secret** from your Connected App

## Step 3: Update OAuth Callback Handler (Future Implementation)

Currently, VaultForce uses the standard Salesforce OAuth callback behavior. For production use, you may want to create a custom callback handler:

1. Create a new Visualforce page or Apex REST endpoint to handle OAuth callbacks
2. The endpoint should:
   - Capture the authorization code from the URL parameter
   - Exchange the code for tokens using `exchangeAuthorizationCode()`
   - Store tokens securely (encrypted in the org record)
   - Redirect the user back to the VaultForce app

## Step 4: Deploy and Test

1. Deploy your updated `OrgService.cls` to your VaultForce org:
```bash
sfdx project deploy start -d force-app
```

2. Navigate to the VaultForce app

3. Click **Connected Salesforce Orgs** > **New Org**

4. Fill in the org details:
   - **Org Name**: Give your org a friendly name
   - **Org Type**: Select the type (Production, Sandbox, Developer, Scratch)
   - **Instance URL**: The Salesforce instance URL (e.g., https://login.salesforce.com)

5. Click **Authorize with OAuth**

6. You'll be redirected to the target org to authorize
   - Log in if prompted
   - Review and approve the connection request

7. After authorization, you'll be returned to VaultForce with an active org connection

## Step 5: Test the Connection

1. In the **Connected Salesforce Orgs** list, find your newly connected org
2. Click **Test Connection** from the row actions
3. You should see a success message confirming the connection is working

## Troubleshooting

### OAuth Error: "Invalid client id"
- Verify your Consumer Key is correct in `OrgService.cls`
- Check that the Consumer Key in your Connected App matches

### OAuth Error: "Invalid client secret"
- Verify your Consumer Secret is correct in `OrgService.cls`
- Consumer Secrets are case-sensitive

### OAuth Error: "invalid_redirect_uri"
- Verify the Callback URL in your Connected App matches the `callbackUrl` in the code
- Default callback URL should be: `https://yourinstance.lightning.force.com/oauth/callback`

### Connection Test Failed: "OAuth credentials not configured"
- Verify you've updated `getClientId()` and `getClientSecret()` in `OrgService.cls`
- Redeploy your changes to the org
- Clear browser cache and try again

### "Token refresh failed"
- The refresh token may have expired
- Reconnect the org by clicking the **Reconnect** action (future enhancement)

## Security Best Practices

### For Production:

1. **Use Named Credentials** instead of storing secrets in code:
   - Create a Named Credential in Salesforce Setup
   - Reference it in the Apex code instead of hardcoding values

2. **Use Environment Variables**:
   - Store OAuth credentials in Salesforce environment-specific files
   - Load them dynamically at runtime

3. **Token Encryption**:
   - VaultForce automatically encrypts tokens using the `EncryptedText` field type
   - No additional configuration needed

4. **Token Expiration**:
   - Implement regular token refresh before expiration
   - Currently handles manual refresh; consider implementing automatic refresh

5. **Revoke Tokens**:
   - When disconnecting an org, revoke the tokens on the target org
   - Remove org record from VaultForce

## Additional Resources

- [Salesforce OAuth Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_oauth.htm)
- [Connected Apps](https://help.salesforce.com/s/articleView?id=sf.connected_app_overview.htm)
- [OAuth Token Lifecycle](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_oauth_token_flow.htm)
