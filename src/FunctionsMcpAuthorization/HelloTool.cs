using FunctionsMcpAuthorization.McpOutboundCredential;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;
using Microsoft.Extensions.Logging;
using Microsoft.Graph;

namespace FunctionsMcpAuthorization;

public class HelloTool(ILogger<HelloTool> logger, IMcpOutboundCredentialProvider credentialProvider)
{
    private static readonly string[] graphDefaultScopes = ["https://graph.microsoft.com/.default"];

    [Function(nameof(HelloTool))]
    public async Task<string> Run(
        [McpToolTrigger(nameof(HelloTool), "Responds to the user with a hello message.")] ToolInvocationContext context
    )
    {
        logger.LogInformation("C# MCP tool trigger function processed a request.");

        var token = credentialProvider.GetTokenCredential().GetToken(new Azure.Core.TokenRequestContext(graphDefaultScopes), CancellationToken.None);

        using var graphClient = new GraphServiceClient(credentialProvider.GetTokenCredential(), graphDefaultScopes);

        try
        {
            var me = await graphClient.Me.GetAsync();
            return $"Hello, {me!.DisplayName} ({me?.Mail})]!";
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error calling Microsoft Graph");
            throw;
        }
    }
}