using Azure.Core;
using Microsoft.Azure.Functions.Worker.Extensions.Mcp;

namespace FunctionsMcpAuthorization.McpOutboundCredential;

public class McpOutboundCredentialProvider : IMcpOutboundCredentialProvider
{
    private TokenCredential? _credential;

    public TokenCredential GetTokenCredential()
    {
        return _credential!;
    }

    internal void SetTokenCredential(TokenCredential tokenCredential)
    {
        _credential = tokenCredential;
    }
}