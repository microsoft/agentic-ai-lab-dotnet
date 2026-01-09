#:package Azure.AI.Agents.Persistent@1.2.0-beta.8
#:package Azure.Identity@1.17.1
#:package dotenv.net@4.0.0
#:package ModelContextProtocol@0.5.0-preview.1
#:package Microsoft.Extensions.Hosting@10.0.1
#:package Microsoft.Extensions.Logging.Console@10.0.1

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using ModelContextProtocol.Server;
using System.ComponentModel;

var builder = Host.CreateApplicationBuilder(args);
builder.Logging.AddConsole(consoleLogOptions =>
{
    // set all logs to go to stderr
    consoleLogOptions.LogToStandardErrorThreshold = LogLevel.Trace;
});

builder.Services
    .AddMcpServer()
    .WithStdioServerTransport()
    .WithTools<InventoryTools>();

await builder.Build().RunAsync();


[McpServerToolType]
public class InventoryTools
{
    private static readonly Dictionary<string, int> _inventory = new()
    {
        ["Moisturizer"] = 6,
        ["Shampoo"] = 8,
        ["Body Spray"] = 28,
        ["Hair Gel"] = 5,
        ["Lip Balm"] = 12,
        ["Skin Serum"] = 9,
        ["Cleanser"] = 30,
        ["Conditioner"] = 3,
        ["Setting Powder"] = 17,
        ["Dry Shampoo"] = 45
    };

    private static readonly Dictionary<string, int> _weeklySales = new()
    {
        ["Moisturizer"] = 22,
        ["Shampoo"] = 18,
        ["Body Spray"] = 3,
        ["Hair Gel"] = 2,
        ["Lip Balm"] = 14,
        ["Skin Serum"] = 19,
        ["Cleanser"] = 4,
        ["Conditioner"] = 1,
        ["Setting Powder"] = 13,
        ["Dry Shampoo"] = 17
    };

    [McpServerTool]
    [Description("Retrieves current inventory levels for all cosmetics products")]
    public static string GetInventoryLevels()
    {
        var lines = _inventory.Select(kvp => $"{kvp.Key}: {kvp.Value} units");
        return string.Join("\n", lines);
    }

    [McpServerTool]
    [Description("Retrieves weekly sales data for all products")]
    public static string GetWeeklySales()
    {
        var lines = _weeklySales.Select(kvp => $"{kvp.Key}: {kvp.Value} units sold last week");
        return string.Join("\n", lines);
    }
}