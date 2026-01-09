# Microsoft Agent Framework Samples (.NET 10)

Practical notebooks and reference material for building Microsoft Agent Framework solutions with **.NET 10 and C#** across agents, workflows, memory, middleware, and observability scenarios.

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Running the Notebooks](#running-the-notebooks)
5. [Repository Guide](#repository-guide)
6. [Suggested Learning Path](#suggested-learning-path)
7. [Troubleshooting](#troubleshooting)
8. [Additional Resources](#additional-resources)

## Overview

The Microsoft Agent Framework is the next generation of tooling from the Semantic Kernel and AutoGen teams. It provides a unified programming model for building intelligent agents, multi-agent workflows, and connected tools in both Python and .NET. These samples showcase core scenarios ranging from single-agent chat to advanced orchestration with state management, custom memory, and production telemetry using **.NET 10 and C#**.

> The framework is currently in public preview. Expect APIs and package names to evolve.

## Prerequisites

- .NET 10 SDK or later
- An Azure subscription with access to Azure AI Foundry (for Azure-hosted samples)
- Azure CLI 2.60+ with an active `az login` session
- Optional: Redis (for distributed thread samples) and Application Insights (for telemetry notebooks)

## Environment Setup

1. **Install packages**  
   Most samples work with the preview roll-up package. Add to your `.csproj`:
   ```xml
   <PackageReference Include="Microsoft.AgentFramework" Version="1.0.0-preview.*" />
   ```
   Or install via CLI:
   ```bash
   dotnet add package Microsoft.AgentFramework --prerelease
   ```
   For slimmer environments you can install the specific integrations you need:
   ```bash
   dotnet add package Microsoft.AgentFramework.Core --prerelease
   dotnet add package Microsoft.AgentFramework.AzureAI --prerelease
   ```

2. **Configure environment variables**  
   Copy the sample file and update the values with your Azure resources:
   ```bash
   cp appsettings.example.json appsettings.json
   ```
   Or use `appsettings.json` directly:
   ```json
   {
     "AzureAI": {
       "ProjectEndpoint": "https://<project-name>.services.ai.azure.com/api/projects/firstProject",
       "ModelDeploymentName": "<deployment-name>",
       "SubscriptionId": "<subscription-id>"
     }
   }
   ```
   Some notebooks require additional settings such as `BingConnectionId` (web grounding) or Redis connection strings (threading samples). The notebook markdown cells call out anything extra.

3. **Verify authentication**  
   Run `az account show` to confirm the CLI is signed in and targeting the correct subscription.

## Running the Notebooks

1. Open the notebook you want to explore in VS Code with the Polyglot Notebooks extension.
2. Execute the cells in order. Most notebooks include setup cells that validate credentials before the scenarios run.

Alternatively, you can run standalone C# samples:
```bash
dotnet run --project <sample-project>
```

## Repository Guide

### `agents/azure_ai_agents/`
Single-agent patterns for the Azure AI chat client. Highlights:
- `azure_ai_basic.ipynb` introduces the agent lifecycle using service-managed storage.
- `azure_ai_with_function_tools.ipynb` demonstrates tool invocation and structured tool output.
- `azure_ai_with_file_search.ipynb` shows retrieval augmented generation with Azure AI file search.
- `azure_ai_with_code_interpreter.ipynb` enables code execution within conversations.

**Example: Basic Agent Setup (C#)**
```csharp
using Azure.AI.Agents.Persistent;
using Azure.Identity;
using Microsoft.Extensions.Configuration;

var config = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json")
    .Build();

var client = new PersistentAgentsClient(
    config["AzureAI:ProjectEndpoint"]!,
    new DefaultAzureCredential());

var agent = await client.Administration.CreateAgentAsync(
    model: config["AzureAI:ModelDeploymentName"]!,
    name: "MyAgent",
    instructions: "You are a helpful assistant.");

var thread = await client.Threads.CreateThreadAsync();

await client.Messages.CreateMessageAsync(
    thread.Value.Id,
    MessageRole.User,
    "Hello, how can you help me today?");

var run = await client.Runs.CreateAndProcessRunAsync(thread.Value.Id, agent.Value.Id);

var messages = await client.Messages.GetMessagesAsync(thread.Value.Id);
Console.WriteLine(messages.Value.Data.Last().Content[0].Text);

// Cleanup
await client.Administration.DeleteAgentAsync(agent.Value.Id);
```

See `agents/azure_ai_agents/README.md` for the complete walkthrough and detailed setup instructions.

### `agents/mcp/`
Model Context Protocol examples that connect Agent Framework to external systems:
- `azure_ai_with_mcp.ipynb` drives an Azure AI agent through the MCP client stack.
- `AgentAsMcpServer.cs` exposes an agent as an MCP server that other clients can query.
- `McpApiKeyAuth.cs` illustrates securing MCP servers with API keys.

**Example: MCP Client Connection (C#)**
```csharp
using ModelContextProtocol.Client;

await using var mcpClient = await McpClientFactory.CreateAsync(
    new McpServerConfig
    {
        Id = "my-server",
        Name = "My MCP Server",
        TransportType = TransportType.StdIo,
        TransportOptions = new()
        {
            ["command"] = "dotnet",
            ["args"] = "run --project ../McpServer"
        }
    });

var tools = await mcpClient.ListToolsAsync();
Console.WriteLine($"Available tools: {string.Join(", ", tools.Select(t => t.Name))}");
```

### `context_providers/`
Memory and context management recipes:
- `1-azure_ai_memory_context_providers.ipynb` extracts, stores, and re-injects conversation facts using the `IContextProvider` APIs.

**Example: Context Provider (C#)**
```csharp
public class ConversationMemoryProvider : IContextProvider
{
    private readonly List<string> _facts = new();

    public Task<string> GetContextAsync(CancellationToken cancellationToken = default)
    {
        return Task.FromResult(string.Join("\n", _facts));
    }

    public Task AddFactAsync(string fact, CancellationToken cancellationToken = default)
    {
        _facts.Add(fact);
        return Task.CompletedTask;
    }
}
```

The accompanying README outlines provider lifecycles and extension points.

### `threads/`
Conversation threading and persistence:
- `1-azure-ai-thread-serialization.ipynb` shows how Azure AI Foundry manages server-side history.
- `2-custom_chat_message_store_thread.ipynb` builds a custom `IChatMessageStore`.
- `3-redis_chat_message_store_thread.ipynb` persists messages to Redis for distributed workloads.
- `4-suspend_resume_thread.ipynb` suspends and resumes threads across sessions.

**Example: Custom Message Store (C#)**
```csharp
public class InMemoryChatMessageStore : IChatMessageStore
{
    private readonly Dictionary<string, List<ChatMessage>> _threads = new();

    public Task SaveMessageAsync(string threadId, ChatMessage message, CancellationToken ct = default)
    {
        if (!_threads.ContainsKey(threadId))
            _threads[threadId] = new List<ChatMessage>();
        
        _threads[threadId].Add(message);
        return Task.CompletedTask;
    }

    public Task<IReadOnlyList<ChatMessage>> GetMessagesAsync(string threadId, CancellationToken ct = default)
    {
        return Task.FromResult<IReadOnlyList<ChatMessage>>(
            _threads.TryGetValue(threadId, out var messages) 
                ? messages 
                : Array.Empty<ChatMessage>());
    }
}
```

Refer to `threads/README.md` for architecture notes and troubleshooting tips.

### `middleware/`
Nine notebooks that cover interception patterns for agents and workflows:
- Request/response interception (`1-agent_and_run_level_middleware.ipynb`)
- Function-based and class-based middleware (`2-` and `3-` prefixed notebooks)
- Error handling, termination, and result overrides (`6-` through `8-`)

**Example: Logging Middleware (C#)**
```csharp
public class LoggingMiddleware : IAgentMiddleware
{
    private readonly ILogger<LoggingMiddleware> _logger;

    public LoggingMiddleware(ILogger<LoggingMiddleware> logger)
    {
        _logger = logger;
    }

    public async Task<AgentResponse> InvokeAsync(
        AgentRequest request,
        AgentMiddlewareDelegate next,
        CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Request: {Message}", request.Message);
        
        var response = await next(request, cancellationToken);
        
        _logger.LogInformation("Response: {Message}", response.Message);
        return response;
    }
}
```

A short README describes when to choose each middleware style.

### `observability/`
Operational telemetry examples:
- `1-azure_ai_agent_observability.ipynb` emits OpenTelemetry traces for agent runs.
- `2-azure_ai_chat_client_with_observability.ipynb` wires telemetry into lower-level chat clients.

**Example: OpenTelemetry Setup (C#)**
```csharp
using OpenTelemetry;
using OpenTelemetry.Trace;
using Azure.Monitor.OpenTelemetry.Exporter;

var tracerProvider = Sdk.CreateTracerProviderBuilder()
    .AddSource("Microsoft.AgentFramework")
    .AddAzureMonitorTraceExporter(options =>
    {
        options.ConnectionString = config["ApplicationInsights:ConnectionString"];
    })
    .Build();

// Agents automatically emit traces when tracing is configured
```

These scenarios focus on Application Insights, but also illustrate custom span annotations.

### `workflows/`
Graph-based orchestration examples (40+ notebooks) arranged by topic:
- `_start-here/` progressive introduction to executors, edges, and streaming.
- `agents/`, `orchestration/`, and `parallelism/` demonstrate complex control flow and coordination.
- `checkpoint/` and `state-management/` show long-running workflow patterns.
- `human-in-the-loop/` and `observability/` bring humans and telemetry into workflow runs.

**Example: Simple Workflow (C#)**
```csharp
using Microsoft.AgentFramework.Workflows;

var workflow = new WorkflowBuilder()
    .AddNode("start", async ctx => 
    {
        ctx.State["input"] = ctx.Input;
        return "process";
    })
    .AddNode("process", async ctx =>
    {
        var input = ctx.State["input"]?.ToString() ?? "";
        ctx.State["result"] = input.ToUpperInvariant();
        return "end";
    })
    .AddNode("end", async ctx =>
    {
        Console.WriteLine($"Result: {ctx.State["result"]}");
        return null; // Terminal node
    })
    .Build();

await workflow.ExecuteAsync("hello world");
```

Start with `_start-here/notebooks/step1_executors_and_edges.ipynb` and move into the thematic folders. The folder-level README provides a map for all scenarios.

### `devui/`
A lightweight web experience for exploring agents and workflows:
- `InMemoryMode.cs` spins up DevUI with local in-memory data.
- Running the DevUI project discovers agents and workflows on disk and serves them at `http://localhost:8080/`.

```bash
dotnet run --project devui
```

Great for demos or rapid iteration without wiring up a full application.

## Suggested Learning Path

1. **Foundations** — Work through `agents/azure_ai_agents/azure_ai_basic.ipynb` and `azure_ai_with_explicit_settings.ipynb`.
2. **Persistence** — Explore the `threads/` notebooks to understand message storage and resume patterns.
3. **Memory** — Add contextual memory using `context_providers/1-azure_ai_memory_context_providers.ipynb`.
4. **Tooling & Integration** — Connect agents to external systems via `agents/mcp/`.
5. **Workflows** — Combine everything in `workflows/_start-here/` before branching into advanced orchestration topics.
6. **Observability** — Instrument runs with the `observability/` notebooks.
7. **Middleware** — Implement cross-cutting concerns with the `middleware/` series.
8. **Interactive UI** — Use `devui/` to demo or validate your agents with a browser-based client.

## Troubleshooting

- **Authentication failures** — Re-run `az login` and confirm your Azure subscription has the required Azure AI permissions.
- **Missing configuration** — Verify `appsettings.json` contains all keys called out in notebook setup cells.
- **Package restore errors** — Ensure you've run `dotnet restore` and that NuGet can access the preview package feeds.
- **Redis connectivity** — Update the connection string in the Redis samples and confirm the service is reachable before running the notebook cells.
- **Application Insights ingestion delay** — Telemetry can take a few minutes to appear in the Azure portal; use the Live Metrics Stream for near-real-time debugging.

## Additional Resources

- Product documentation: <https://learn.microsoft.com/en-us/agent-framework/overview/agent-framework-overview>
- GitHub repository: <https://github.com/microsoft/agent-framework>
- Microsoft AI guidance: <https://learn.microsoft.com/azure/ai-services/>
- .NET 10 Documentation: <https://learn.microsoft.com/en-us/dotnet/>
- Azure AI Agents SDK for .NET: <https://learn.microsoft.com/en-us/dotnet/api/azure.ai.agents/>

Keep an eye on release notes in the official documentation for API or package updates while the framework remains in preview.
