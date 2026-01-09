using System;
using System.Text.Json;
using Azure.Identity;
using System.Threading.Tasks;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace azure_function;

public class FooReply
{
    private readonly QueueClient _outputQueue;
    private readonly ILogger<FooReply> _logger;

    public FooReply(
        ILogger<FooReply> logger)
    {
        _logger = logger;

        var storageServiceEndpoint = Environment.GetEnvironmentVariable("STORAGE_SERVICE_ENDPOINT")
            ?? throw new InvalidOperationException("Missing STORAGE_SERVICE_ENDPOINT");

        _outputQueue = new QueueClient(
            new Uri($"{storageServiceEndpoint}/azure-function-tool-output"),
            new DefaultAzureCredential(),
            new QueueClientOptions { MessageEncoding = QueueMessageEncoding.Base64 });

        _outputQueue.CreateIfNotExists();
    }

    [Function(nameof(FooReply))]
    public async Task Run([QueueTrigger("azure-function-foo-input", Connection = "STORAGE_SERVICE_ENDPOINT")] QueueMessage message)
    {
        _logger.LogInformation("Azure Function triggered with a queue item.");

        using JsonDocument doc = JsonDocument.Parse(message.MessageText);
        var root = doc.RootElement;
        var userQuery = root.TryGetProperty("query", out var q) ? q.GetString() ?? string.Empty : string.Empty;
        var correlationId = root.TryGetProperty("CorrelationId", out var c) ? c.GetString() ?? string.Empty : string.Empty;

        var result = new
        {
            FooReply = $"This is Foo, responding to: {userQuery}! Stay strong 💪!",
            CorrelationId = correlationId
        };

        await _outputQueue.SendMessageAsync(JsonSerializer.Serialize(result));
        _logger.LogInformation("Sent message: {Result}", JsonSerializer.Serialize(result));
    }
}