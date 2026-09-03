// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

using System.Text.Json.Serialization;

namespace SearchParams;

public sealed class ParseRequest
{
    [JsonPropertyName("text")]
    public string Text { get; set; } = "";

    [JsonPropertyName("timeZoneOffset")]
    public int TimeZoneOffset { get; set; }
}
