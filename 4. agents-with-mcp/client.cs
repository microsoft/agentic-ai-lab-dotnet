#:package Microsoft.Agents.AI.AzureAI.Persistent@1.0.0-preview.260108.1
#:package Azure.Identity@1.17.1
#:package dotenv.net@4.0.0
#:package ModelContextProtocol@0.5.0-preview.1
#:package Microsoft.Extensions.Hosting@10.0.1
#:package Microsoft.Extensions.Logging.Console@10.0.1

using Microsoft.Agents.AI;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Client;
using Azure.Identity;
using System.ComponentModel;
using dotenv.net;
using Azure.AI.Agents.Persistent;
using System.ClientModel;
using Microsoft.Extensions.AI;
using ModelContextProtocol.Protocol;

// Load the environment variables from the .env file
DotEnv.Load(new DotEnvOptions(envFilePaths: new[] { Path.Combine(".", "..", ".env") }));

// get the project endpoint
var projectEndpoint = Environment.GetEnvironmentVariable("AI_FOUNDRY_PROJECT_ENDPOINT");

var modelDeployment = Environment.GetEnvironmentVariable("MODEL_DEPLOYMENT_NAME");

// verify config
Console.WriteLine($"Using project endpoint: {projectEndpoint}");
Console.WriteLine($"Using model deployment: {modelDeployment}");

if (string.IsNullOrEmpty(projectEndpoint) || string.IsNullOrEmpty(modelDeployment))
{
    Console.WriteLine("Please set the AI_FOUNDRY_PROJECT_ENDPOINT and MODEL_DEPLOYMENT_NAME environment variables in the .env file.");
    return 1;
}

static async Task<McpClient> ConnectToServer()
{
    // create the mcp stdio server host
    var clientTransport = new StdioClientTransport(new()
    {
        Name = "inventory",
        Command = "dotnet",
        Arguments = new[] { "run", "./server.cs" }
    });

    // start the mcp server
    var mcpClient = await McpClient.CreateAsync(clientTransport!);

    // list available tools
    var tools = await mcpClient.ListToolsAsync();

    return mcpClient;
}

static ToolDefinition MakeFunctionToolForMcpTool(McpClientTool tool)
{
    return new FunctionToolDefinition(
        tool.Name,
        tool.Description);
}

async Task ChatLoop(McpClient mcpClient)
{
    var agentsClient = new PersistentAgentsClient(
        endpoint: projectEndpoint!,
        credential: new InteractiveBrowserCredential()
    );

    var tools = await mcpClient.ListToolsAsync();

    var toolDefinitions = new List<ToolDefinition>();

    foreach (var tool in tools)
    {
        toolDefinitions.Add(MakeFunctionToolForMcpTool(tool));
    }

    // create the agent
    var agent = await agentsClient.Administration.CreateAgentAsync(
        model: modelDeployment!,
        name: "InventoryAgent",
        instructions:
            """
            You are an inventory assistant. Here are some general guidelines:
            - Recommend restock if item inventory < 10 and weekly sales > 15
            - Recommend clearance if item inventory > 20 and weekly sales < 5
            """,
        tools: toolDefinitions.ToArray()
    );

    // Create a thread for the conversation
    PersistentAgentThread thread = await agentsClient.Threads.CreateThreadAsync();
    PersistentThreadMessage? message = null;

    PromptForInput();
    while (Console.ReadLine() is string query && !"exit".Equals(query, StringComparison.OrdinalIgnoreCase))
    {
        if (string.IsNullOrEmpty(query))
        {
            PromptForInput();
        }

        // Send user message
        message = await agentsClient.Messages.CreateMessageAsync(
            thread.Id,
            MessageRole.User,
            query
        );

        List<ToolApproval> toolApprovals = [];
        List<ToolOutput> toolOutputs = [];
        ThreadRun? streamRun = null;
        AsyncCollectionResult<StreamingUpdate> stream = agentsClient.Runs.CreateRunStreamingAsync(
            thread.Id,
            agent.Value.Id
        );

        do
        {
            toolApprovals.Clear();
            toolOutputs.Clear();

            await foreach (StreamingUpdate streamingUpdate in stream)
            {
                if (streamingUpdate.UpdateKind == StreamingUpdateReason.RunCreated)
                {
                    Console.WriteLine("--- Run Started! ---");
                }
                else if (streamingUpdate is SubmitToolApprovalUpdate submitToolApprovalUpdate)
                {
                    Console.WriteLine(
                        $"Approving MCP tool call: {submitToolApprovalUpdate.Name}, Arguments: {submitToolApprovalUpdate.Arguments}");
                    toolApprovals.Add(new ToolApproval(submitToolApprovalUpdate.ToolCallId, approve: true));
                    streamRun = submitToolApprovalUpdate.Value;
                }
                else if (streamingUpdate is MessageContentUpdate contentUpdate)
                {
                    Console.Write(contentUpdate.Text);
                }
                else if (streamingUpdate is RequiredActionUpdate submitToolOutputsUpdate)
                {
                    RequiredActionUpdate newActionUpdate = submitToolOutputsUpdate;
                    var toolOutput = await GetResolvedToolOutput(
                        newActionUpdate.FunctionName,
                        newActionUpdate.ToolCallId,
                        mcpClient);
                    if (toolOutput is not null)
                        toolOutputs.Add(toolOutput);
                    
                    streamRun = submitToolOutputsUpdate.Value;
                }
                else if (streamingUpdate is RunStepUpdate runStepUpdate)
                {
                    PrintActivityStep(runStepUpdate);
                }
                else if (streamingUpdate.UpdateKind == StreamingUpdateReason.RunCompleted)
                {
                    Console.WriteLine();
                    Console.WriteLine("--- Run Completed! ---");
                }
                else if (streamingUpdate.UpdateKind == StreamingUpdateReason.Error &&
                         streamingUpdate is RunUpdate errorStep)
                {
                    Console.WriteLine($"Error: {errorStep.Value.LastError}");
                }
            }

            if (toolOutputs.Count > 0)
            {
                stream = agentsClient.Runs.SubmitToolOutputsToStreamAsync(streamRun, toolOutputs: toolOutputs);
            }

            if (toolApprovals.Count > 0)
            {
                stream = agentsClient.Runs.SubmitToolOutputsToStreamAsync(streamRun, toolOutputs: toolOutputs, toolApprovals);
            }
        } while (toolApprovals.Count > 0 || toolOutputs.Count > 0);
    }
}

static void PromptForInput()
{
    Console.WriteLine("Enter a command (or 'exit' to quit):");
    Console.ForegroundColor = ConsoleColor.Cyan;
    Console.Write("> ");
    Console.ResetColor();
}

static async Task<ToolOutput?> GetResolvedToolOutput(string functionName, string toolCallId, McpClient mcpClient)
{
    var tools = await mcpClient.ListToolsAsync();

    
    foreach (var tool in tools)
    {
        if (tool.Name == functionName)
        {
            var toolOutput = await mcpClient.CallToolAsync(
                tool.Name);

            return new ToolOutput(toolCallId, toolOutput.Content.OfType<TextContentBlock>().First().Text);
        }
    }
    return null;
}

async Task<int> MainAsync()
{
    // connect to the MCP server
    McpClient? mcpClient = null;
    try
    {
        Console.WriteLine("Connecting to MCP server...");
        mcpClient = await ConnectToServer();

        // create the persistent agent client
        await ChatLoop(mcpClient);
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error: {ex.Message}");
        if (mcpClient is not null)
        {
            await mcpClient.DisposeAsync();
        }
        return -1;
    }

    return 0;
}

static void PrintActivityStep(RunStep step)
{
    if (step.StepDetails is RunStepActivityDetails activityDetails)
    {
        foreach (RunStepDetailsActivity activity in activityDetails.Activities)
        {
            foreach (KeyValuePair<string, ActivityFunctionDefinition> activityFunction in activity.Tools)
            {
                Console.WriteLine($"The function {activityFunction.Key} with description \"{activityFunction.Value.Description}\" will be called.");
                if (activityFunction.Value.Parameters.Properties.Count > 0)
                {
                    Console.WriteLine("Function parameters:");
                    foreach (KeyValuePair<string, FunctionArgument> arg in activityFunction.Value.Parameters.Properties)
                    {
                        Console.WriteLine($"\t{arg.Key}");
                        Console.WriteLine($"\t\tType: {arg.Value.Type}");
                        if (!string.IsNullOrEmpty(arg.Value.Description))
                            Console.WriteLine($"\t\tDescription: {arg.Value.Description}");
                    }
                }
                else
                {
                    Console.WriteLine("This function has no parameters");
                }
            }
        }
    }
}

return await MainAsync();