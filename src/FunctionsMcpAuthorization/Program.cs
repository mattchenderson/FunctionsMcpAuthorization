using FunctionsMcpAuthorization.McpOutboundCredential;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

builder.Services.AddScoped<IMcpOutboundCredentialProvider, McpOutboundCredentialProvider>();
builder.UseWhen<McpOutboundCredentialMiddleware>((context) => context.FunctionDefinition.InputBindings.Values.First(a => a.Type.EndsWith("Trigger")).Type == "mcpToolTrigger");

builder.Build().Run();
