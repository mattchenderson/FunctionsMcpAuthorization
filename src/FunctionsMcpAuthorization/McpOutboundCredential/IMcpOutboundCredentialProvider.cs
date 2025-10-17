using Azure.Core;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace FunctionsMcpAuthorization.McpOutboundCredential;

public interface IMcpOutboundCredentialProvider
{
    public TokenCredential GetTokenCredential();
}
