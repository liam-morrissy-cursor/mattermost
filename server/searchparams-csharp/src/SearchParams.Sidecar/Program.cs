// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

using System.Text.Json;
using SearchParams;

var jsonOptions = new JsonSerializerOptions
{
    PropertyNameCaseInsensitive = true,
};

Console.Error.WriteLine("ready");
Console.Error.Flush();

while (true)
{
    var line = Console.In.ReadLine();
    if (line is null)
    {
        break;
    }

    if (string.IsNullOrWhiteSpace(line))
    {
        continue;
    }

    SearchParamsResult[] result;
    try
    {
        var request = JsonSerializer.Deserialize<ParseRequest>(line, jsonOptions) ?? new ParseRequest();
        result = SearchParamsParser.Parse(request.Text, request.TimeZoneOffset);
    }
    catch (JsonException)
    {
        result = [];
    }

    Console.Out.WriteLine(JsonSerializer.Serialize(result, jsonOptions));
    Console.Out.Flush();
}
