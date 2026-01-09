# MCP Inventory Management Agent (.NET 10)

This project demonstrates how to connect AI agents to tools using the **Model Context Protocol (MCP)** with **.NET 10 and C#**. The implementation creates an intelligent inventory management agent for a cosmetics retailer that can automatically discover and use tools to analyze inventory levels and provide actionable recommendations.

## 🎯 What You'll Build

- **MCP Client** (`McpClient`): An Azure AI agent that connects to MCP servers and automatically uses discovered tools
- **MCP Server** (`McpServer`): A local server providing inventory management tools via MCP protocol
- **Interactive Chat**: A conversational interface where the agent analyzes inventory and provides smart recommendations

## 🏗️ Architecture Overview

```
┌─────────────────┐    MCP Protocol     ┌─────────────────┐
│   Azure AI      │ ◄─────────────────► │   MCP Server    │
│   Agent Client  │   (stdio transport) │   (McpServer)   │
│   (McpClient)   │                     │                 │
└─────────────────┘                     └─────────────────┘
         │                                       │
         │ Calls tools automatically             │ Provides tools:
         │ based on user queries                 │ • GetInventoryLevels
         └───────────────────────────────────────│ • GetWeeklySales
```

## 📋 Prerequisites

Before running this project, ensure you have:

1. **.NET 10 SDK** installed
2. **Azure AI Foundry project** with deployed models
3. **Git** (for cloning the repository)
4. **Azure authentication** set up

## 🚀 Quick Start

### Step 1: Clone and Setup Environment

```bash
# Clone the repository
git clone <repository-url>
cd agentic-ai-lab-dotnet

# Navigate to the MCP project directory
cd "4. agents-with-mcp"
```

### Step 2: Configure Azure Authentication

The project uses the existing configuration. Authenticate using one of these methods:

**Option A: Azure CLI (Recommended)**
```bash
az login
```

**Option B: Environment Variables**
The `.env` file already contains your Azure project configuration.

### Step 3: Verify Your Configuration

The project will automatically use these values from the root `.env` file:
- `AI_FOUNDRY_PROJECT_ENDPOINT`: Your Azure AI project endpoint
- `MODEL_DEPLOYMENT_NAME`: Your deployed model (currently: `gpt-4o`)
- `TENANT_ID`: Your Azure tenant ID

### Step 4: Run the MCP Demo

The client automatically starts the MCP server, so you only need one command:

```bash
cd "4. agents-with-mcp"
dotnet run ./client.cs
```

You should see output like:
```
Project Endpoint: https://your-project.services.ai.azure.com/api/projects/your-project
Model Deployment: gpt-4o
Connected to server with tools: [GetInventoryLevels, GetWeeklySales]
Enter a prompt for the inventory agent. Use 'quit' to exit.
USER: 
```

**Note**: The McpClient automatically:
1. Starts the MCP server internally
2. Establishes the MCP protocol connection 
3. Discovers available tools
4. Creates the Azure AI agent with tool access
5. Provides the interactive chat interface

### Step 5: Test the Agent

Try these example prompts:

```
Please analyze our current inventory and provide recommendations

What items need restocking urgently?

Which products should we put on clearance sale?

Show me all inventory levels and sales data

What's our overall inventory health?
```

Type `quit` to exit the application.

## 📁 Project Structure

```
agentic-ai-lab-dotnet/
├── appsettings.json              # ✅ Root configuration (already configured)
├── 4. agents-with-mcp/           # 👈 MCP demonstration
│   ├── client.cs                 # MCP client with Azure AI integration
│   ├── server.cs                 # MCP server with inventory tools
│   └── README.md                 # This file
├── 3. agents/                    # Other agent examples
├── 2. chat-rag/                  # RAG examples
└── ...                           # Other lab modules
```

## 🔧 How It Works

### MCP Server (`McpServer`)

```csharp
using ModelContextProtocol.Server;
using System.ComponentModel;

var builder = McpServerBuilder.Create(args);

builder.WithStdioServerTransport()
       .WithToolsFromAssembly();

var server = builder.Build();
await server.RunAsync();

// Tool definitions
public static class InventoryTools
{
    private static readonly Dictionary<string, InventoryItem> _inventory = new()
    {
        ["Moisturizer"] = new("Moisturizer", 6, "Skincare"),
        ["Shampoo"] = new("Shampoo", 8, "Haircare"),
        ["Skin Serum"] = new("Skin Serum", 9, "Skincare"),
        ["Body Spray"] = new("Body Spray", 28, "Body Care"),
        ["Cleanser"] = new("Cleanser", 30, "Skincare"),
        ["Dry Shampoo"] = new("Dry Shampoo", 45, "Haircare")
    };

    private static readonly Dictionary<string, int> _weeklySales = new()
    {
        ["Moisturizer"] = 22,
        ["Shampoo"] = 18,
        ["Skin Serum"] = 19,
        ["Body Spray"] = 3,
        ["Cleanser"] = 4,
        ["Dry Shampoo"] = 12
    };

    [McpTool("get_inventory_levels")]
    [Description("Retrieves current inventory levels for all cosmetics products")]
    public static string GetInventoryLevels()
    {
        var result = _inventory.Select(kvp => 
            $"{kvp.Key}: {kvp.Value.Quantity} units ({kvp.Value.Category})");
        return string.Join("\n", result);
    }

    [McpTool("get_weekly_sales")]
    [Description("Retrieves weekly sales data for all products")]
    public static string GetWeeklySales()
    {
        var result = _weeklySales.Select(kvp => 
            $"{kvp.Key}: {kvp.Value} units sold last week");
        return string.Join("\n", result);
    }
}

public record InventoryItem(string Name, int Quantity, string Category);
```

### MCP Client (`McpClient`)

```csharp
using Azure.AI.Agents.Persistent;
using Azure.Identity;
using ModelContextProtocol.Client;
using Microsoft.Extensions.Configuration;

var config = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json")
    .AddEnvironmentVariables()
    .Build();

var projectEndpoint = config["AzureAI:ProjectEndpoint"]!;
var modelDeploymentName = config["AzureAI:ModelDeploymentName"]!;

Console.WriteLine($"Project Endpoint: {projectEndpoint}");
Console.WriteLine($"Model Deployment: {modelDeploymentName}");

// Start MCP server and connect
await using var mcpClient = await McpClientFactory.CreateAsync(
    new McpServerConfig
    {
        Id = "inventory-server",
        Name = "Inventory MCP Server",
        TransportType = TransportType.StdIo,
        TransportOptions = new()
        {
            ["command"] = "dotnet",
            ["args"] = "run --project ../McpServer"
        }
    });

// Discover tools from MCP server
var tools = await mcpClient.ListToolsAsync();
Console.WriteLine($"Connected to server with tools: [{string.Join(", ", tools.Select(t => t.Name))}]");

// Create Azure AI Agent client
var agentsClient = new PersistentAgentsClient(
    projectEndpoint, 
    new DefaultAzureCredential());

// Convert MCP tools to Azure AI function definitions
var functionTools = tools.Select(tool => new FunctionToolDefinition(
    name: tool.Name,
    description: tool.Description,
    parameters: BinaryData.FromObjectAsJson(tool.InputSchema)
)).ToList();

// Create agent with MCP tools
var agent = await agentsClient.Administration.CreateAgentAsync(
    model: modelDeploymentName,
    name: "Inventory Agent",
    instructions: """
        You are an intelligent inventory management agent for a cosmetics retailer.
        Analyze inventory levels and sales data to provide actionable recommendations.
        Focus on identifying items that need restocking and products for clearance.
        """,
    tools: functionTools
);

var thread = await agentsClient.Threads.CreateThreadAsync();

Console.WriteLine("Enter a prompt for the inventory agent. Use 'quit' to exit.");

while (true)
{
    Console.Write("USER: ");
    var userInput = Console.ReadLine();
    
    if (string.IsNullOrWhiteSpace(userInput) || userInput.Equals("quit", StringComparison.OrdinalIgnoreCase))
        break;

    await agentsClient.Messages.CreateMessageAsync(
        thread.Value.Id,
        MessageRole.User,
        userInput);

    var run = await agentsClient.Runs.CreateRunAsync(thread.Value.Id, agent.Value.Id);
    
    // Poll for completion and handle tool calls
    while (run.Value.Status == RunStatus.InProgress || 
           run.Value.Status == RunStatus.RequiresAction)
    {
        await Task.Delay(500);
        
        if (run.Value.Status == RunStatus.RequiresAction)
        {
            var toolOutputs = new List<ToolOutput>();
            
            foreach (var toolCall in run.Value.RequiredAction.SubmitToolOutputs.ToolCalls)
            {
                Console.WriteLine($"📊 Calling tool: {toolCall.Function.Name}");
                
                // Execute MCP tool
                var result = await mcpClient.CallToolAsync(
                    toolCall.Function.Name,
                    JsonSerializer.Deserialize<Dictionary<string, object>>(
                        toolCall.Function.Arguments));
                
                toolOutputs.Add(new ToolOutput(toolCall.Id, result.Content.ToString()));
            }
            
            run = await agentsClient.Runs.SubmitToolOutputsToRunAsync(
                thread.Value.Id, 
                run.Value.Id, 
                toolOutputs);
        }
        
        run = await agentsClient.Runs.GetRunAsync(thread.Value.Id, run.Value.Id);
    }

    // Get and display response
    var messages = await agentsClient.Messages.GetMessagesAsync(thread.Value.Id);
    var lastMessage = messages.Value.Data
        .Where(m => m.Role == MessageRole.Assistant)
        .OrderByDescending(m => m.CreatedAt)
        .FirstOrDefault();

    if (lastMessage != null)
    {
        Console.WriteLine($"\nAGENT:\n{lastMessage.Content[0].Text}\n");
    }
}

// Cleanup
await agentsClient.Administration.DeleteAgentAsync(agent.Value.Id);
Console.WriteLine("Agent session ended.");
```

### Key Features

1. **Automatic Tool Discovery**: Client discovers server tools without hardcoding
2. **Intelligent Recommendations**: Agent provides business insights based on data
3. **Real-time Analysis**: Tools are called dynamically based on user queries  
4. **Professional Output**: Structured recommendations with reasoning
5. **Error Handling**: Robust error handling and graceful degradation

## 💡 Example Interaction

```
USER: Please analyze our current inventory and provide recommendations

🔧 Agent is calling MCP tools...
📊 Calling tool: GetInventoryLevels
📊 Calling tool: GetWeeklySales

AGENT:
Based on the current inventory levels and weekly sales data, here are my recommendations:

**URGENT RESTOCK NEEDED:**
- Moisturizer: Only 6 units left but sold 22 last week - HIGH DEMAND
- Shampoo: Only 8 units left but sold 18 last week - RESTOCK IMMEDIATELY
- Skin Serum: Only 9 units left but sold 19 last week - LOW STOCK ALERT

**CLEARANCE RECOMMENDATIONS:**
- Body Spray: 28 units in stock but only 3 sold - EXCESS INVENTORY
- Cleanser: 30 units in stock but only 4 sold - CONSIDER PROMOTION
- Dry Shampoo: 45 units in stock, selling moderately - MONITOR

**BUSINESS INSIGHTS:**
- Top performers: Moisturizer, Shampoo, and Skin Serum show strong demand
- Slow movers: Body care products need marketing attention
- Inventory turnover: Focus on high-velocity skincare items
```

## 🛠️ Troubleshooting

### Common Issues

**"Could not find a part of the path... McpServer.csproj"**
```bash
# Make sure you're in the correct directory
cd "4. agents-with-mcp"

# Verify project structure exists
dotnet build McpServer
dotnet build McpClient
```

**"DefaultAzureCredential failed"**
```bash
# Authenticate with Azure
az login

# Or check if you're signed into VS Code with Azure Account extension
```

**"Server connection failed"**
- The client automatically starts the server, so this error indicates:
  - `McpServer` project is missing or has build errors
  - .NET SDK issues preventing server startup
  - File permissions preventing execution
- Ensure you're in the `4. agents-with-mcp` directory when running `dotnet run --project McpClient`
- Run `dotnet build` to check for compilation errors

**"Agent creation failed"**  
- Verify your `appsettings.json` has correct Azure project details
- Check that your deployed model name matches `AzureAI:ModelDeploymentName`
- Ensure you have proper permissions in Azure AI Foundry

### Debug Mode

Enable detailed logging to troubleshoot issues:

```csharp
// Add to Program.cs
using Microsoft.Extensions.Logging;

var loggerFactory = LoggerFactory.Create(builder =>
{
    builder.AddConsole();
    builder.SetMinimumLevel(LogLevel.Debug);
});

// Or use appsettings.json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "ModelContextProtocol": "Debug"
    }
  }
}
```

## 🎓 Learning Objectives

After completing this demo, you'll understand:

1. **MCP Protocol**: How AI agents discover and use external tools
2. **stdio Transport**: Communication between MCP clients and servers  
3. **Azure AI Integration**: Connecting MCP tools to Azure AI agents with .NET
4. **Dynamic Function Calling**: How agents decide when to use tools
5. **Business Intelligence**: Converting raw data into actionable insights

## 🔄 Next Steps

**Extend the Demo:**
- Add more inventory tools (purchase orders, supplier data)
- Connect to real inventory databases using Entity Framework Core
- Implement different recommendation algorithms
- Add visualization tools with Blazor

**Deploy to Production:**  
- Host MCP server in Azure Container Apps
- Use Azure AI Foundry for agent deployment
- Implement authentication and rate limiting
- Add comprehensive error handling and logging with Application Insights

**Explore Other MCP Servers:**
- Try the [Azure MCP Server](https://github.com/Azure/azure-mcp) 
- Build custom MCP servers for your business needs
- Integrate with external APIs and services

## 📚 Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [Azure AI Foundry](https://ai.azure.com/)
- [Azure AI Agents SDK for .NET](https://learn.microsoft.com/en-us/dotnet/api/azure.ai.agents/)
- [MCP .NET SDK](https://github.com/modelcontextprotocol/csharp-sdk)
- [.NET 10 Documentation](https://learn.microsoft.com/en-us/dotnet/)

## 🐛 Support

For issues:
- **Azure AI Services**: [Azure Support](https://azure.microsoft.com/support/)
- **MCP Protocol**: [MCP Community](https://modelcontextprotocol.io/community/)  
- **This Demo**: Create an issue in the repository

---

**🎉 Happy Building!** This demo shows the power of MCP for creating intelligent, tool-aware AI agents with .NET that can adapt to different business scenarios.
