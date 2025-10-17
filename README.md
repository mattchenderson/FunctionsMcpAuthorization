# Sample: MCP server authorization with Azure Functions

This sample shows how to use App Service Authentication and Authorization for Model Context Protocol (MCP) server authorization. The MCP server is implemented using the Azure Functions MCP Extension. The sample also shows how to call the Microsoft Graph on behalf of the signed-in user.

The sample uses a .NET project. There are two ways to get started:

- [You can deploy the application to Azure using the Azure Developer CLI (azd)](#get-started-deploy-to-azure-with-azd) - this is the recommended way to get started with the sample.
- [You can run the application locally](#get-started-run-locally) - this option does not use any MCP server authorization. Instead of using the identity of the authorized user, it uses your developer credentials for outbound calls to the Microsoft Graph. The option is covered for completeness and to show how you might build your own applications to work locally, but it is not the core focus of the sample.

You can run it locally or quickly deploy it to Azure using the Azure Developer CLI (azd).

## Prerequisites

- An Azure subscription - [Create an Azure free account](https://azure.microsoft.com/free/)
- Azure CLI - [Install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Azure Developer CLI (azd) - [Install the Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd?tabs=azure-cli)
- Azure Functions Core Tools - [Install the Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?pivots=programming-language-csharp#install-the-azure-functions-core-tools)
- .NET SDK 8.0 or later - [Install the .NET SDK](https://dotnet.microsoft.com/download/dotnet/)
- Visual Studio Code - [Install Visual Studio Code](https://code.visualstudio.com/download)
- Azurite - [Install Azurite](https://learn.microsoft.com/azure/storage/common/storage-install-azurite)

You must also have an Entra client ID that can be used by your MCP client. For basic testing, you can use Visual Studio Code, which has a known client ID explained in the setup instructions below.

## Get started (deploy to Azure with `azd`)

1. Clone this repository.
1. Sign in to Azure and initialize azd:

    ```cli
    az login
    azd auth login
    ```

1. Create a new azd project environment, specifying a location (`westus2` is recommended), the subscription ID you want to use, and a name for the environment:

    ```cli
    azd env new <environment-name> --location westus2 --subscription <subscription-id>
    ```

1. This sample uses Visual Studio Code as the main client. Configure the it as an allowed client application:

    ```cli
    azd env set PRE_AUTHORIZED_CLIENT_IDS aebc6443-996d-45c2-90f0-388ff96faa56
    ```

    If you have other MCP clients that will call your server, provide all of the client IDs as a comma-separated list:

    ```cli
    azd env set PRE_AUTHORIZED_CLIENT_IDS <comma-separated-list-of-client-ids>
    ```

1. Specify a service management reference if required by your organization. **If you're not a Microsoft employee and don't know that you need to set this, you can skip this step.** However, if provisioning fails with an error about a missing service management reference, you may need to revisit this step. Microsoft employees using a Microsoft tenant must provide a service management reference (your Service Tree ID). Without this, you won't be able to create the Entra app registration, and provisioning will fail.

    ```cli
    azd env set SERVICE_MANAGEMENT_REFERENCE <service-management-reference>
    ```

    If you don't know what to set here, check with your organization's tenant administrator.

1. (Optional) If you are deploying to a sovereign cloud, set the token exchange audience used for that cloud.

    For Entra ID US Government:

    ```cli
    azd env set TOKEN_EXCHANGE_AUDIENCE api://AzureADTokenExchangeUSGov
    ```

    For Entra ID China operated by 21Vianet:

    ```cli
    azd env set TOKEN_EXCHANGE_AUDIENCE api://AzureADTokenExchangeChina
    ```

1. Create the Azure resources and deploy the application:

    ```cli
    azd up
    ```

    Ensure all resources show as "Succeeded" status before proceeding.

1. Consent to the application so your MCP client can successfully sign you in. For testing, you'll author consent just for yourself by logging into the application in a browser. See [Consent authoring](#consent-authoring) for how you would handle this for production scenarios.

    1. Navigate to the `/.auth/login/aad` endpoint of your deployed function app. For example, if your function app is at `https://my-mcp-function-app.azurewebsites.net`, navigate to `https://my-mcp-function-app.azurewebsites.net/.auth/login/aad`.

        Your function app base URL should be shown in the output of the `azd up` command. If you missed it in the deployment output, you can retrieve it with:

        ```cli
        azd env get-value SERVICE_MCP_DEFAULT_HOSTNAME
        ```

        Or find it in the Azure portal under your Function App resource.

    1. You should be redirected to a login prompt. Sign in with the account you will use from the MCP client for testing.

    1. After signing in, you will be prompted to consent to the application. Review the permissions requested and click "Accept" to grant consent.

    1. You should be redirected back to a page hosted at the function app URL saying "you have successfully signed in". You can close the page at this point.

1. Get your Function App's MCP extension system key for connecting MCP clients. Your client will need this key to call your MCP server, in addition to server authorization with Entra ID.

    You can obtain the system key named `mcp_extension` using the Azure CLI. First, get the resource group and function app names from your azd deployment:

    ```cli
    # Get resource group name
    azd env get-value AZURE_RESOURCE_GROUP_NAME
    
    # Get function app name  
    azd env get-value SERVICE_MCP_NAME
    ```

    Then use these values to retrieve the system key:

    ```cli
    az functionapp keys list --resource-group <resource_group> --name <function_app_name> --query "systemKeys.mcp_extension" -o tsv
    ```

    Alternatively, you can retrieve it from the [Azure portal](https://learn.microsoft.com/azure/azure-functions/function-keys-how-to?tabs=azure-portal):
    1. Navigate to your Function App in the Azure portal
    1. Go to **Functions** → **App keys**  
    1. Copy the value for the `mcp_extension` system key

1. Test your MCP server by following the instructions in the [Test your MCP server](#test-your-mcp-server) section below. You'll need your function app URL and the `mcp_extension` system key from the previous step.

## Get started (run locally)

> [!NOTE]
> When running locally, the MCP server will use your developer credentials (from Azure CLI or Visual Studio Code) for outbound calls to Microsoft Graph instead of an authorized user's identity.

1. Clone this repository.

1. (Optional) Update the `local.settings.json` file in the `src/FunctionsMcpAuthorization` folder to include your Microsoft Entra tenant ID. This helps the application correctly access your developer identity, even when you can sign into multiple tenants.

    1. Obtain the tenant ID from the Azure CLI:

        ```cli
        az account show --query tenantId -o tsv
        ```

    1. Update `local.settings.json` to include the tenant ID:

        ```json
        {
          "IsEncrypted": false,
          "Values": {
            "AzureWebJobsStorage": "UseDevelopmentStorage=true",
            "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
            "AZURE_TENANT_ID": "<your-tenant-id>"
          }
        }
        ```

1. Start Azurite. If you are using the CLI to start it up, with an `azurite` or a `docker run` command, for example, do so in a separate background terminal.

1. Move your main terminal to the `src/FunctionsMcpAuthorization` folder.

1. Start the project:

    ```dotnetcli
    dotnet run
    ```

1. Test your MCP server by following the instructions in the [Test your MCP server](#test-your-mcp-server) section below.

## Test your MCP server

Once you've completed one of the "Get started" options above, you can test your resulting MCP server by connecting to it with an MCP client.

The instructions provided below are for testing with GitHub Copilot in Visual Studio Code, which supports both the MCP protocol and Entra ID authentication. This setup also provides logs that make it easy to see how the client and server interact for server authorization.

1. Create a new workspace in VS Code and install the [MCP extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode.mcp).

1. **Create or update your MCP configuration** in VS Code. Add this to your `mcp.json` file (or create one):

    ```json
    {
        "inputs": [
            {
                "type": "promptString",
                "id": "functions-mcp-extension-system-key",
                "description": "Azure Functions MCP Extension System Key",
                "password": true
            },
            {
                "type": "promptString",
                "id": "functionapp-host",
                "description": "The host domain of the function app."
            }
        ],
        "servers": {
            "remote-mcp-function": {
                "type": "http",
                "url": "https://${input:functionapp-host}/runtime/webhooks/mcp",
                "headers": {
                    "x-functions-key": "${input:functions-mcp-extension-system-key}"
                }
            },
            "local-mcp-function": {
                "type": "http",
                "url": "http://localhost:7071/runtime/webhooks/mcp"
            }
        }
    }
    ```

    This creates two server configurations, one for each "Get started" option above. For subsequent steps, choose the server that matches how you set up your MCP server, local or remote.

1. (Optional) **Show the output logs**:
   - In VS Code, open the Command Palette:
     - On Windows/Linux: Press `Ctrl+Shift+P`
     - On Mac: Press `Cmd+Shift+P`
   - Type "MCP: List Servers" and press Enter
   - Select the server you want to start (either `remote-mcp-function` or `local-mcp-function`)
   - Choose "Show Output" - this will open the output pane.
   - Select the gear icon in the output pane and select "Debug" or higher. "Trace" provides the most detail but might include additional noise.

1. **Start the MCP server**:
   - In VS Code, open the Command Palette:
     - On Windows/Linux: Press `Ctrl+Shift+P`
     - On Mac: Press `Cmd+Shift+P`
   - Type "MCP: List Servers" and press Enter
   - Select the server you want to start (either `remote-mcp-function` or `local-mcp-function`)
   - Choose "Start Server".
   - If you chose `remote-mcp-function`, you will be prompted for:
     - Your Function App URL
     - Your `mcp_extension` system key

1. If you're connecting to the app hosted behind App Service Authentication and Authorization, VS Code will prompt you to allow GitHub Copilot to access your Microsoft account. Follow the prompts to sign in.

    If you configured debug output logs, you should see how the MCP client and server interact during the sign-in process. See [Server authorization protocol](#server-authorization-protocol) for more details.

1. Open the GitHub Copilot chat pane (`Ctrl+Alt+I`) and enter a prompt to use the tool. The easiest way to ensure it invokes the tool is to send the message `#HelloTool`.
1. GitHub Copilot should prompt you to allow it to call the tool. Verify that it's going to the right server and then allow it to proceed.
1. You should see a response from the tool in the chat pane. It should greet you by name and show your email. This information comes from the Microsoft Graph, which the MCP server calls.

## Conceptual overview

### Code structure

The code for the MCP server is in the `src/FunctionsMcpAuthorization` project folder. This is an Azure Functions project that uses the MCP Extension for Azure Functions, defining one tool in `HelloTool.cs`. The goal of this function is to call the Microsoft Graph and return simple greeting. When hosted in Azure, it will call the Graph on behalf of the signed-in user for the request. When run locally, it will use your developer credentials.

To meet these requirements, the function class uses dependency injection to obtain a token for the correct user. The `Program.cs` file registers a scoped service for this purpose. The service is scoped because each request may be for a different user, so we need to create a new instance for each request.

The Program.cs file also registers a function middleware for MCP triggers. This middleware is what identifies the user context and configures the scoped service with the appropriate `Azure.Core.TokenCredential` instance. In local contexts, this is a simple `ChainedTokenCredential`. However, when hosted in Azure with App Service Authentication and Authorization, the middleware uses the MCP tool trigger's `ToolInvocationContext` to access the headers from the underlying HTTP transport. It uses these headers to craft a custom `TokenCredential` implementation. This implementation uses the `OnBehalfOfCredential`, authenticating as the app registration using a managed identity as a federated identity credential, which was set up during provisioning.

The approach of using a scoped service and a function middleware is convenient for configuring per-request dependencies like user context. It also keeps the tool implementation simple and focused on its core purpose, without introducing any extra identity code. This also allows the same setup to be used across multiple tools if needed. The service, middleware, custom credential, and supporting helpers are all found within the `McpOutboundCredential` folder.

It is worth noting that the local development setup is made simple because the sample application only needs the `User.Read` permission for the Microsoft Graph. This is one of the permissions that is requested by default with the Graph. If additional, specific permissions were needed, the app would need to obtain a token that includes the correct permission claims. The correct way to do this would be to leverage a custom client registration for development time, mirroring the app registration used in the full Azure deployment. Accommodating this is outside the scope of this sample, but it is something to consider when building your own applications.

### Consent authoring

In the steps described for this example, you consented to the application by signing into it in a browser. This allowed the application to request delegated permissions to the Microsoft Graph. There are two main ways that consent can be handled:

- **User consent** - This is the approach used in the example above. Each user signs into the application and consents to the permissions requested. They can only do this for themselves, unless they are a tenant administrator with the ability to consent on behalf of others. In this sample, user consent is appropriate because it allows you to quickly test things without impacting other users. However, the way user consent is authored in this sample does not reflect how you would typically do it in a production scenario. This is described in more detail below.
- **Admin consent** - A tenant administrator can consent to the application on behalf of all users when they sign in and review the permissions. Once this is done, individual users can sign in without needing to consent themselves. This approach is more scalable and ensures that all users can access the application without running into consent issues. For the purposes of a sample, admin consent is not appropriate, but it is a great choice for production scenarios.

The user consent approach for this sample is a separate login because the sample uses Visual Studio Code as the client. Although Visual Studio Code is pre-authorized to our application, that only creates consent for the user to call the MCP server. It doesn't create consent for the MCP server to call the Microsoft Graph on behalf of the user. When we log into the application directly, we request Microsoft Graph permissions as part of a combined consent experience.

The main difference is that because Visual Studio Code is using a single sign-on flow, so it only requests a token for the MCP server. It does not present an opportunity for the user to interactively consent to any permissions needed for or by the MCP server. If you built a client that used an interactive login of some kind, you could have it all handled entirely by that client. It would not be necessary to have a separate browser login.

See [Overview of permissions and consent in the Microsoft identity platform](https://learn.microsoft.com/entra/identity-platform/permissions-consent-overview) for additional information on how Entra ID handles consent.

### Server authorization protocol

In the debug output from VS Code, you'll see a series of requests and responses as the MCP client and server interact. When MCP server authorization is used, you should see the following sequence of events:

1. The editor sends an initialization request to the MCP server.
1. The MCP server responds with an error indicating that authorization is required. The response includes a pointer to the protected resource metadata (PRM) for the application. The App Service Authentication and Authorization feature generates the PRM for an app built with this sample.
1. The editor fetches the PRM and uses it to identify the authorization server.
1. The editor attempts to obtain authorization server metadata (ASM) from a well-known endpoint on the authorization server.
1. Microsoft Entra ID doesn't support ASM on the well-known endpoint, so the editor falls back to using the OpenID Connect metadata endpoint to obtain the ASM. It tries to discover this using by inserting the well-known endpoint before any other path information.
1. The OpenID Connect specifications actually defined the well-known endpoint as being after path information, and that is where Microsoft Entra ID hosts it. So the editor tries again with that format.
1. The editor successfully retrieves the ASM. It then can then use this information in conjunction with its own client ID to perform a login. At this point, the editor prompts you to sign in and consent to the application.
1. Assuming you successfully sign in and consent, the editor completes the login. It repeats the intialization request to the MCP server, this time including an authorization token in the request. This reattempt isn't visible at the Debug output level, but you can see it in the Trace output level.
1. The MCP server validates the token and responds with a successful response to the initialization request. The standard MCP flow continues from this point, ultimately resulting in discovery of the MCP tool defined in this sample.

You can learn more about the full protocol in the [MCP specification](https://modelcontextprotocol.io/specification/2025-06-18/basic/authorization).
