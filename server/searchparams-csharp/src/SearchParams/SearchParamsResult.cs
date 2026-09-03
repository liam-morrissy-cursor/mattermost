// Copyright (c) 2015-present Mattermost, Inc. All Rights Reserved.
// See LICENSE.txt for license information.

using System.Text.Json.Serialization;

namespace SearchParams;

// JSON names match server/public/model.SearchParams so the Go adapter can unmarshal the sidecar response.
public sealed class SearchParamsResult
{
    [JsonPropertyName("terms")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string Terms { get; set; } = "";

    [JsonPropertyName("excluded_terms")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string ExcludedTerms { get; set; } = "";

    [JsonPropertyName("ishashtag")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool IsHashtag { get; set; }

    [JsonPropertyName("in_channels")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? InChannels { get; set; }

    [JsonPropertyName("excluded_channels")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? ExcludedChannels { get; set; }

    [JsonPropertyName("from_users")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? FromUsers { get; set; }

    [JsonPropertyName("excluded_users")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? ExcludedUsers { get; set; }

    [JsonPropertyName("after_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string AfterDate { get; set; } = "";

    [JsonPropertyName("excluded_after_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string ExcludedAfterDate { get; set; } = "";

    [JsonPropertyName("before_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string BeforeDate { get; set; } = "";

    [JsonPropertyName("excluded_before_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string ExcludedBeforeDate { get; set; } = "";

    [JsonPropertyName("extensions")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? Extensions { get; set; }

    [JsonPropertyName("excluded_extensions")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string[]? ExcludedExtensions { get; set; }

    [JsonPropertyName("on_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string OnDate { get; set; } = "";

    [JsonPropertyName("excluded_date")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public string ExcludedDate { get; set; } = "";

    [JsonPropertyName("or_terms")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool OrTerms { get; set; }

    [JsonPropertyName("include_deleted_channels")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool IncludeDeletedChannels { get; set; }

    [JsonPropertyName("timezone_offset")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public int TimeZoneOffset { get; set; }

    [JsonPropertyName("search_without_user_id")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingDefault)]
    public bool SearchWithoutUserId { get; set; }

    [JsonPropertyName("modifier")]
    public string Modifier { get; set; } = "";
}
