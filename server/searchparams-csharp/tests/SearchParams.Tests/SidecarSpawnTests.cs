// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

using System.Diagnostics;
using System.Text.Json;

namespace SearchParams.Tests;

public class SidecarSpawnTests
{
    [Fact]
    public async Task PublishedSidecar_StartsAndServesTwoRequests()
    {
        var sidecarPath = await PublishSidecarAsync();
        using var process = StartSidecar(sidecarPath);

        try
        {
            await WaitForReadyAsync(process);

            var first = await SendAsync(process, """{"text":"hello","timeZoneOffset":-28800}""");
            Assert.Single(first);
            Assert.Equal("hello", first[0].Terms);
            Assert.Equal(-28800, first[0].TimeZoneOffset);

            var second = await SendAsync(process, """{"text":"","timeZoneOffset":0}""");
            Assert.Empty(second);

            Assert.False(process.HasExited, "sidecar must stay alive across requests");
        }
        finally
        {
            if (!process.HasExited)
            {
                process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync();
            }
        }
    }

    private static async Task<string> PublishSidecarAsync()
    {
        var fromEnv = Environment.GetEnvironmentVariable("SEARCHPARAMS_SIDECAR");
        if (!string.IsNullOrEmpty(fromEnv) && File.Exists(fromEnv))
        {
            return Path.ChangeExtension(fromEnv, ".dll");
        }

        var sidecarProject = FindSidecarProject();
        var publishDir = Path.Combine(Path.GetTempPath(), "searchparams-sidecar-smoke", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(publishDir);

        var publish = Process.Start(new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"publish \"{sidecarProject}\" -c Release -o \"{publishDir}\" --nologo",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        }) ?? throw new InvalidOperationException("failed to start dotnet publish");

        var stdout = await publish.StandardOutput.ReadToEndAsync();
        var stderr = await publish.StandardError.ReadToEndAsync();
        await publish.WaitForExitAsync();
        Assert.True(publish.ExitCode == 0, $"dotnet publish failed ({publish.ExitCode}):\n{stdout}\n{stderr}");

        var dll = Path.Combine(publishDir, "SearchParams.Sidecar.dll");
        Assert.True(File.Exists(dll), $"published sidecar missing at {dll}");
        return dll;
    }

    private static string FindSidecarProject()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null)
        {
            var candidate = Path.Combine(dir.FullName, "src", "SearchParams.Sidecar", "SearchParams.Sidecar.csproj");
            if (File.Exists(candidate))
            {
                return candidate;
            }

            dir = dir.Parent;
        }

        throw new FileNotFoundException("could not locate SearchParams.Sidecar.csproj from " + AppContext.BaseDirectory);
    }

    private static Process StartSidecar(string sidecarPath)
    {
        var start = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = $"exec \"{sidecarPath}\"",
            WorkingDirectory = Path.GetDirectoryName(sidecarPath),
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
        };
        start.Environment["DOTNET_EnableDiagnostics"] = "0";

        var process = Process.Start(start) ?? throw new InvalidOperationException("failed to start sidecar");
        process.StandardInput.AutoFlush = true;
        return process;
    }

    private static async Task WaitForReadyAsync(Process process)
    {
        var stderr = new List<string>();
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        while (!cts.IsCancellationRequested)
        {
            var line = await process.StandardError.ReadLineAsync(cts.Token);
            if (line is null)
            {
                process.WaitForExit(1000);
                throw new InvalidOperationException(
                    $"sidecar exited before writing ready (exit {process.ExitCode}). stderr:\n{string.Join('\n', stderr)}");
            }

            stderr.Add(line);
            if (line.Trim() == "ready")
            {
                return;
            }
        }
    }

    private static async Task<SearchParamsResult[]> SendAsync(Process process, string request)
    {
        await process.StandardInput.WriteLineAsync(request);

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        var line = await process.StandardOutput.ReadLineAsync(cts.Token);
        Assert.False(string.IsNullOrWhiteSpace(line), "sidecar returned no response");

        var result = JsonSerializer.Deserialize<SearchParamsResult[]>(line!);
        Assert.NotNull(result);
        return result!;
    }
}
